@IsTest
private class DKD_UnsubscribeResourceTest {

    private static Id personRecordType() {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
    }

    private static Contact personContact() {
        Account a = new Account(RecordTypeId = personRecordType(), FirstName = 'Jana', LastName = 'Testová',
            PersonEmail = 'jana.testova@example.com', CRMforNonProfit__Newsletter__pc = true);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.duplicateRuleHeader.allowSave = true;
        Database.insert(a, dml);
        return [SELECT Id, AccountId, DKD_Unsubscribe_Token__c FROM Contact WHERE AccountId = :a.Id];
    }

    private static void request(String method, String token) {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/odhlaseni';
        req.httpMethod = method;
        if (token != null) req.params.put('t', token);
        RestContext.request = req;
        RestContext.response = new RestResponse();
    }

    private static String body() { return RestContext.response.responseBody.toString(); }

    @IsTest
    static void personAccountGetsTokenAndUnsubscribes() {
        Contact c = personContact();
        System.assert(String.isNotBlank(c.DKD_Unsubscribe_Token__c), 'Osobni ucet musi dostat token');
        System.assertEquals(32, c.DKD_Unsubscribe_Token__c.length());

        // GET nesmi odhlasit - odkazy otevira i antispam
        request('GET', c.DKD_Unsubscribe_Token__c);
        DKD_UnsubscribeResource.showPage();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assert(body().contains('<form method="post"'));
        System.assertEquals(true, [SELECT CRMforNonProfit__Newsletter__pc FROM Account WHERE Id = :c.AccountId].CRMforNonProfit__Newsletter__pc);

        request('POST', c.DKD_Unsubscribe_Token__c.toUpperCase());
        Test.startTest();
        DKD_UnsubscribeResource.unsubscribe();
        Test.stopTest();
        System.assertEquals(200, RestContext.response.statusCode);
        System.assertEquals(false, [SELECT CRMforNonProfit__Newsletter__pc FROM Account WHERE Id = :c.AccountId].CRMforNonProfit__Newsletter__pc);
        List<Task> tasks = [SELECT Subject, Status, WhoId FROM Task WHERE WhoId = :c.Id];
        System.assertEquals(1, tasks.size());
        System.assertEquals(DKD_UnsubscribeResource.SUBJECT, tasks[0].Subject);
        System.assertEquals('Completed', tasks[0].Status);

        // podruhe uz jen informace, zadna dalsi aktivita
        request('POST', c.DKD_Unsubscribe_Token__c);
        DKD_UnsubscribeResource.unsubscribe();
        request('GET', c.DKD_Unsubscribe_Token__c);
        DKD_UnsubscribeResource.showPage();
        System.assert(body().contains('Už jste odhlášeni'));
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhoId = :c.Id]);
    }

    @IsTest
    static void businessContactUnsubscribes() {
        Account company = new Account(Name = 'Firma Test s.r.o.');
        insert company;
        Contact c = new Contact(AccountId = company.Id, LastName = 'Novák', Email = 'novak@example.com', CRMforNonProfit__Newsletter__c = true);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.duplicateRuleHeader.allowSave = true;
        Database.insert(c, dml);
        c = [SELECT Id, DKD_Unsubscribe_Token__c FROM Contact WHERE Id = :c.Id];
        System.assert(String.isNotBlank(c.DKD_Unsubscribe_Token__c), 'Kontakt musi dostat token');

        request('POST', c.DKD_Unsubscribe_Token__c);
        DKD_UnsubscribeResource.unsubscribe();
        System.assertEquals(false, [SELECT CRMforNonProfit__Newsletter__c FROM Contact WHERE Id = :c.Id].CRMforNonProfit__Newsletter__c);
        System.assertEquals(1, [SELECT COUNT() FROM Task WHERE WhoId = :c.Id AND Subject = :DKD_UnsubscribeResource.SUBJECT]);
    }

    @IsTest
    static void invalidTokenIsRejected() {
        personContact();
        for (String t : new List<String>{ null, '', 'abc', '<script>', '0123456789abcdef0123456789abcdef' }) {
            request('GET', t);
            DKD_UnsubscribeResource.showPage();
            System.assertEquals(400, RestContext.response.statusCode, 'Token ' + t);
            request('POST', t);
            DKD_UnsubscribeResource.unsubscribe();
            System.assertEquals(400, RestContext.response.statusCode, 'Token ' + t);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Task WHERE Subject = :DKD_UnsubscribeResource.SUBJECT]);
    }

    @IsTest
    static void existingTokenIsKept() {
        Contact c = new Contact(LastName = 'Vlastní', DKD_Unsubscribe_Token__c = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.duplicateRuleHeader.allowSave = true;
        Database.insert(c, dml);
        System.assertEquals('aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', [SELECT DKD_Unsubscribe_Token__c FROM Contact WHERE Id = :c.Id].DKD_Unsubscribe_Token__c);
    }
}
