@IsTest
private class DKD_GiftThankYouServiceTest {

    private static final String TEST_TEMPLATE = 'DKD_Thank_You_Test_Tmp';
    private static final String TEST_TEMPLATE_RECURRING = 'DKD_Thank_You_Rec_Tmp';
    private static final String TEST_PDF = 'DKD test PDF';

    @TestSetup
    static void setup() {
        // EmailTemplate jde v testu vlozit jen do osobni slozky uzivatele
        System.runAs(new User(Id = UserInfo.getUserId())) {
            insert new EmailTemplate(
                Name = 'DKD test',
                DeveloperName = TEST_TEMPLATE,
                TemplateType = 'custom',
                FolderId = UserInfo.getUserId(),
                IsActive = true,
                Subject = 'Dekujeme {!GiftTransaction.Thank_You_Donor_Name__c}',
                HtmlValue = '<p>Dar {!GiftTransaction.Thank_You_Amount__c} Kc, {!GiftTransaction.Thank_You_Donor_Name__c}</p>',
                Body = 'Dar {!GiftTransaction.Thank_You_Amount__c} Kc'
            );
            insert new EmailTemplate(
                Name = 'DKD test pravidelny',
                DeveloperName = TEST_TEMPLATE_RECURRING,
                TemplateType = 'custom',
                FolderId = UserInfo.getUserId(),
                IsActive = true,
                Subject = 'Dekujeme, ze v tom jedete s nami',
                HtmlValue = '<p>Pravidelne {!GiftTransaction.Thank_You_Amount__c} Kc</p>',
                Body = 'Pravidelne {!GiftTransaction.Thank_You_Amount__c} Kc'
            );
        }
        insert new npc_bridge__PDF_Template__c(
            Name = TEST_PDF, npc_bridge__Active__c = true, npc_bridge__Body__c = '<p>{!Name}</p>'
        );
    }

    private static Account makeDonor(String email) {
        Id rtId = [SELECT Id FROM RecordType WHERE SobjectType = 'Account' AND DeveloperName = 'PersonAccount' LIMIT 1].Id;
        Account donor = new Account(RecordTypeId = rtId, FirstName = 'Test', LastName = 'Darce', PersonEmail = email,
            PersonMailingStreet = 'Ulice 1', PersonMailingCity = 'Praha', PersonMailingPostalCode = '110 00');
        insert donor;
        return donor;
    }

    private static GiftTransaction makeGift(Id donorId, Decimal amount) {
        GiftTransaction gt = new GiftTransaction(Name = 'Test dar', DonorId = donorId, PaymentMethod = 'Credit Card',
            OriginalAmount = amount, Status = 'Unpaid', TransactionDate = Date.today());
        insert gt;
        return gt;
    }

    // Jen standardni pole - trida se nasazuje samostatne, bez balicku src-comgate-npc
    private static GiftCommitment makeCommitment(Id donorId) {
        GiftCommitment gc = new GiftCommitment(Name = 'Test zavazek', DonorId = donorId, Status = 'Active',
            EffectiveStartDate = Date.today().addMonths(-1));
        insert gc;
        return gc;
    }

    private static GiftTransaction makeRecurringGift(Id donorId, Id commitmentId, Decimal amount, Date dueDate) {
        GiftTransaction gt = new GiftTransaction(Name = 'Test splatka', DonorId = donorId, PaymentMethod = 'Credit Card',
            OriginalAmount = amount, Status = 'Paid', TransactionDate = dueDate, TransactionDueDate = dueDate,
            GiftCommitmentId = commitmentId);
        insert gt;
        return gt;
    }

    private static void useTestTemplates() {
        DKD_GiftThankYouService.emailTemplateDevName = TEST_TEMPLATE;
        DKD_GiftThankYouService.recurringTemplateDevName = TEST_TEMPLATE_RECURRING;
        DKD_GiftThankYouService.pdfTemplateName = TEST_PDF;
        // v testu neni overena organizacni adresa k dispozici
        DKD_GiftThankYouService.requireOrgWideAddress = false;
    }

    @IsTest
    static void sendsEmailStoresPdfAndMarksSent() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 1500);

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, outcomes.size());
        Assert.isTrue(outcomes[0].success, outcomes[0].message);
        Assert.areEqual('darce@example.com', outcomes[0].recipientEmail);
        Assert.areEqual(1, emails, 'Ma probehnout jedno odeslani');
        GiftTransaction after = [SELECT AcknowledgementStatus, AcknowledgementDate, TaxReceiptStatus FROM GiftTransaction WHERE Id = :gt.Id];
        Assert.areEqual('Sent', after.AcknowledgementStatus);
        Assert.areEqual('Sent', after.TaxReceiptStatus);
        Assert.areEqual(Date.today(), after.AcknowledgementDate);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :gt.Id], 'PDF ma byt ulozene u transakce');
    }

    @IsTest
    static void mergesTemplateTokensFromTransaction() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 1500);
        gt = [SELECT Id, Thank_You_Amount__c, Thank_You_Donor_Name__c FROM GiftTransaction WHERE Id = :gt.Id];

        String merged = DKD_GiftThankYouService.mergeTokens('Dar {!GiftTransaction.Thank_You_Amount__c} pro {!GiftTransaction.Thank_You_Donor_Name__c} a {!GiftTransaction.Neexistuje__c}.', gt);

        Assert.areEqual('1 500', gt.Thank_You_Amount__c);
        Assert.areEqual('Test Darce', gt.Thank_You_Donor_Name__c);
        Assert.areEqual('Dar 1 500 pro Test Darce a .', merged);
        Assert.areEqual(new Set<String>{ 'Thank_You_Amount__c', 'Name' },
            DKD_GiftThankYouService.extractTokenFields('{!GiftTransaction.Thank_You_Amount__c} {!GiftTransaction.Name}'));
    }

    @IsTest
    static void donorWithoutEmailIsLoggedNotSent() {
        useTestTemplates();
        Account donor = makeDonor(null);
        GiftTransaction gt = makeGift(donor.Id, 300);

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });
        Test.stopTest();

        Assert.isFalse(outcomes[0].success);
        Assert.areNotEqual('Sent', [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :gt.Id].AcknowledgementStatus);
        Assert.areEqual(1, [SELECT COUNT() FROM CRMforNonProfit__Error_Log__c WHERE CRMforNonProfit__Record_Id__c = :String.valueOf(gt.Id)]);
    }

    @IsTest
    static void alreadySentIsSkipped() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 300);
        update new GiftTransaction(Id = gt.Id, AcknowledgementStatus = 'Sent');

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.isTrue(outcomes[0].success);
        Assert.areEqual(0, emails, 'Nic se nema posilat');
    }

    @IsTest
    static void missingTemplateIsLogged() {
        DKD_GiftThankYouService.emailTemplateDevName = 'Neexistujici_Sablona';
        DKD_GiftThankYouService.pdfTemplateName = TEST_PDF;
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 300);

        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });

        Assert.isFalse(outcomes[0].success);
        Assert.isTrue(outcomes[0].message.contains('sablona'));
    }

    @IsTest
    static void invocablePublishesEventTriggerEnqueuesAndQueueableProcesses() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 500);
        DKD_GiftThankYouService.Request req = new DKD_GiftThankYouService.Request();
        req.giftTransactionId = gt.Id;
        DKD_GiftThankYouService.Request duplicate = new DKD_GiftThankYouService.Request();
        duplicate.giftTransactionId = gt.Id;

        Test.startTest();
        DKD_GiftThankYouService.enqueue(new List<DKD_GiftThankYouService.Request>{ req, duplicate, null });
        DKD_GiftThankYouService.enqueue(new List<DKD_GiftThankYouService.Request>());
        // Doruci event triggeru DKD_ThankYouRequestedTrigger, ten zaradi Queueable, stopTest ho spusti
        Test.getEventBus().deliver();
        Test.stopTest();

        Assert.areEqual('Sent', [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :gt.Id].AcknowledgementStatus);
        Assert.areEqual(1, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :gt.Id], 'Duplicitni pozadavek nesmi vytvorit druhe potvrzeni');
    }

    @IsTest
    static void eventHandlerIgnoresInvalidAndForeignIds() {
        Test.startTest();
        DKD_GiftThankYouService.handleRequestedEvents(new List<DKD_Thank_You_Requested__e>{
            new DKD_Thank_You_Requested__e(Gift_Transaction_Id__c = 'nesmysl'),
            new DKD_Thank_You_Requested__e(Gift_Transaction_Id__c = UserInfo.getUserId()),
            new DKD_Thank_You_Requested__e(),
            null
        });
        Assert.areEqual(0, Limits.getQueueableJobs(), 'Bez platneho Id transakce se nic neradi do fronty');
        Test.stopTest();
    }

    @IsTest
    static void queueableSplitsIntoChunks() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        List<GiftTransaction> gifts = new List<GiftTransaction>();
        for (Integer i = 0; i < DKD_GiftThankYouService.CHUNK_SIZE + 5; i++) {
            gifts.add(new GiftTransaction(Name = 'Dar ' + i, DonorId = donor.Id, PaymentMethod = 'Credit Card',
                OriginalAmount = 100, Status = 'Unpaid', TransactionDate = Date.today()));
        }
        insert gifts;
        List<Id> ids = new List<Id>(new Map<Id, GiftTransaction>(gifts).keySet());

        Test.startTest();
        new DKD_GiftThankYouQueueable(ids).execute(null);
        Test.stopTest();

        Assert.areEqual(DKD_GiftThankYouService.CHUNK_SIZE,
            [SELECT COUNT() FROM GiftTransaction WHERE Id IN :ids AND AcknowledgementStatus = 'Sent'],
            'Prvni davka odeslana, zbytek ceka na dalsi job');
    }

    @IsTest
    static void schedulerPicksUpPendingOneTimePaidGifts() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftTransaction paid = makeGift(donor.Id, 500);
        update new GiftTransaction(Id = paid.Id, Status = 'Paid');
        GiftTransaction unpaid = makeGift(donor.Id, 500);

        Test.startTest();
        Integer found = DKD_GiftThankYouScheduler.enqueuePending();
        DKD_GiftThankYouScheduler.scheduleEveryQuarterHour();
        new DKD_GiftThankYouScheduler().execute(null);
        Test.stopTest();

        Assert.isTrue(found >= 1, 'Zaplaceny jednorazovy dar ma byt dobran');
        Assert.areEqual(4, [SELECT COUNT() FROM CronTrigger WHERE CronJobDetail.Name LIKE 'DKD podekovani za dar%']);
        Assert.areEqual('Sent', [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :paid.Id].AcknowledgementStatus);
        Assert.areNotEqual('Sent', [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :unpaid.Id].AcknowledgementStatus);
    }

    @IsTest
    static void withoutVerifiedOrgWideAddressNothingIsSent() {
        useTestTemplates();
        DKD_GiftThankYouService.requireOrgWideAddress = true;
        // Skutecna darci@ uz je v orgu overena, test proto miri na adresu, ktera neexistuje
        DKD_GiftThankYouService.fromAddress = 'neexistujici-adresa@example.com';
        Account donor = makeDonor('darce@example.com');
        GiftTransaction gt = makeGift(donor.Id, 500);

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });
        Integer emails = Limits.getEmailInvocations();
        Boolean ready = DKD_GiftThankYouService.isFromAddressReady();
        Integer enqueued = DKD_GiftThankYouScheduler.enqueuePending();
        Test.stopTest();

        Assert.isFalse(outcomes[0].success);
        Assert.isTrue(outcomes[0].message.contains('neexistujici-adresa@example.com'), outcomes[0].message);
        Assert.areEqual(0, emails, 'Bez organizacni adresy nesmi nic odejit');
        Assert.isFalse(ready);
        Assert.areEqual(0, enqueued, 'Dozorci job bez adresy nic neradi do fronty');
        Assert.areEqual('To Be Sent', [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :gt.Id].AcknowledgementStatus);
    }

    // Prvni zaplacena platba zavazku: dekovny e-mail ze sablony pro pravidelny dar, BEZ PDF potvrzeni
    // a bez sahnuti na TaxReceiptStatus. Drive to posilal primo flow akci emailSimple z organizacni
    // adresy, coz z guest kontextu neproslo a shodilo cely zapis platby z Comgate webhooku.
    @IsTest
    static void recurringFirstPaidPaymentSendsWithoutPdf() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftCommitment commitment = makeCommitment(donor.Id);
        GiftTransaction gt = makeRecurringGift(donor.Id, commitment.Id, 500, Date.today());

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.areEqual(1, outcomes.size());
        Assert.isTrue(outcomes[0].success, outcomes[0].message);
        Assert.areEqual(1, emails, 'Ma probehnout jedno odeslani');
        GiftTransaction after = [SELECT AcknowledgementStatus, AcknowledgementDate, TaxReceiptStatus
            FROM GiftTransaction WHERE Id = :gt.Id];
        Assert.areEqual('Sent', after.AcknowledgementStatus);
        Assert.areEqual(Date.today(), after.AcknowledgementDate);
        Assert.areNotEqual('Sent', after.TaxReceiptStatus, 'K pravidelnemu daru se potvrzeni o daru neposila');
        Assert.areEqual(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :gt.Id],
            'K pravidelnemu daru se nepriklada PDF');
    }

    // Dalsi splatka zavazku uz podekovani nedostane
    @IsTest
    static void recurringLaterPaymentIsSkipped() {
        useTestTemplates();
        Account donor = makeDonor('darce@example.com');
        GiftCommitment commitment = makeCommitment(donor.Id);
        makeRecurringGift(donor.Id, commitment.Id, 500, Date.today().addMonths(-1));
        GiftTransaction later = makeRecurringGift(donor.Id, commitment.Id, 500, Date.today());

        Test.startTest();
        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ later.Id });
        Integer emails = Limits.getEmailInvocations();
        Test.stopTest();

        Assert.isTrue(outcomes[0].success, outcomes[0].message);
        Assert.areEqual(0, emails, 'Za dalsi splatku zavazku se uz nedekuje');
        GiftTransaction after = [SELECT AcknowledgementStatus FROM GiftTransaction WHERE Id = :later.Id];
        Assert.areNotEqual('Sent', after.AcknowledgementStatus);
    }

    // Pravidelny dar sahne po sablone pro pravidelny dar, ne po jednorazove
    @IsTest
    static void recurringPicksRecurringTemplate() {
        useTestTemplates();
        DKD_GiftThankYouService.recurringTemplateDevName = 'Neexistujici_Pravidelna_Sablona';
        Account donor = makeDonor('darce@example.com');
        GiftCommitment commitment = makeCommitment(donor.Id);
        GiftTransaction gt = makeRecurringGift(donor.Id, commitment.Id, 500, Date.today());

        List<DKD_GiftThankYouService.Outcome> outcomes = DKD_GiftThankYouService.process(new List<Id>{ gt.Id });

        Assert.isFalse(outcomes[0].success);
        Assert.isTrue(outcomes[0].message.contains('Neexistujici_Pravidelna_Sablona'), outcomes[0].message);
    }
}
