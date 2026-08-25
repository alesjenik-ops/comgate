@IsTest
public with sharing class DonationPageControllerTest {

    @TestSetup
    public static void testSetup(){
        ComgateTestFactory.createComgateSettings();

        Comgate_Settings__c settings = Comgate_Settings__c.getOrgDefaults();
        settings.Day_Of_Charging__c = 0;
        update settings;

        Account donor = ComgateTestFactory.getDonor();
        insert donor;
    }

    @IsTest
    public static void test_getFieldSetWrapper_missing(){
        Test.startTest();
        try{
            DonationPageController.getFieldSetWrapper(null, null, null);
        } catch (Exception e){
            System.assertEquals('Field set not found!', e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    public static void test_getFieldSetWrapper_existingDonor(){
        FieldSet donationFieldSet = Account.SObjectType.getDescribe().fieldSets.getMap().get('DonationPageFieldSet');
        Id donorId = [SELECT Id FROM Account LIMIT 1].Id;
        if(donationFieldSet == null) return;

        Test.startTest();
        String returnJSON = DonationPageController.getFieldSetWrapper(donationFieldSet?.getName(), donorId, null);
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        List<Object> wrappers = (List<Object>) returnMap.get('fieldSetWrapper');
        Object donor = (Object) returnMap.get('donor');

        System.assert(wrappers != null);
        System.assertEquals(donationFieldSet.fields.size(), wrappers.size());
        System.assert(donor != null);
    }

    @IsTest
    public static void test_getReferenceId_personAccount_new(){
        Account donor = ComgateTestFactory.getDonor();
        Contact con = ComgateTestFactory.getContact();
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(
            JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true
        );
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');

        Account donorAssert = [SELECT Id, PersonLeadSource FROM Account WHERE PersonEmail =: donor.PersonEmail];
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals('Donation Page', donorAssert.PersonLeadSource);
    }

    @IsTest
    public static void test_getReferenceId_personAccount_existing(){
        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        Contact con = ComgateTestFactory.getContact();
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(
            JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true
        );
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');

        Account donorAssert = [SELECT Id, PersonLeadSource FROM Account WHERE Id =: donor.Id];
        System.assertEquals(1, [SELECT COUNT() FROM Account]);
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals(null, donorAssert.PersonLeadSource);
    }

    @IsTest
    public static void test_getReferenceId_businessAccount_withContact(){
        Account donor = new Account(Name = 'Test Business', CRMforNonProfit__ICO__c = '12345678');
        Contact con = ComgateTestFactory.getContact();
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(
            JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), false
        );
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');

        Account donorAssert = [SELECT Id FROM Account WHERE Name = 'Test Business'];
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(1, [SELECT COUNT() FROM Contact WHERE AccountId =: donorAssert.Id]);
    }

    @IsTest
    public static void test_getReferenceId_honeypot(){
        Account donor = ComgateTestFactory.getDonor();
        Contact con = ComgateTestFactory.getContact();
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();
        paymentWrapper.privacyAgreement = true;

        Test.startTest();
        try{
            DonationPageController.getReferenceId(
                JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true
            );
            Assert.fail('Exception expected');
        } catch (Exception e){
            Assert.isTrue(e.getMessage().contains('cannot be processed'));
        }
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Payment_Reference__c]);
    }

    @IsTest
    public static void test_createComgatePayment(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentCreatedResponse());

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, null);
        insert paymentReference;
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('oneoff', 200, 'card', 'https://test.test/donation');

        Test.startTest();
        String redirect = DonationPageController.createComgatePayment(paymentReference.Id, JSON.serialize(donor), null, JSON.serialize(paymentWrapper));
        Test.stopTest();

        Assert.areEqual(ComgateMockTest.REDIRECT_URL, redirect);
    }

    @IsTest
    public static void test_createComgatePayment_withCampaignBankAccount(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentCreatedResponse());

        Campaign cam = ComgateTestFactory.getCampaign();
        cam.Comgate_Bank_Account__c = 'none';
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, cam.Id);
        insert paymentReference;
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('oneoff', 200, 'card', 'https://test.test/donation');

        Test.startTest();
        String redirect = DonationPageController.createComgatePayment(paymentReference.Id, JSON.serialize(donor), cam.Id, JSON.serialize(paymentWrapper));
        Test.stopTest();

        Assert.areEqual(ComgateMockTest.REDIRECT_URL, redirect);
    }

    @IsTest
    public static void test_createRelatedRecords_oneOff(){
        Campaign cam = ComgateTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('oneoff', 48, 'card', null);

        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, cam.Id);
        paymentReference.JSON_Account__c = JSON.serialize(donor);
        paymentReference.JSON_Payment_Wrapper__c = JSON.serialize(paymentWrapper);
        paymentReference.Account__c = donor.Id;
        insert paymentReference;

        Test.startTest();
        DonationPageController.createRelatedRecords(paymentReference.Id, donor.Id);
        Test.stopTest();

        GiftTransaction giftTransaction = [SELECT Id, DonorId, Payment_Method__c, Status, CampaignId,
                OriginalAmount, TransactionDueDate, ProcessorReference FROM GiftTransaction LIMIT 1];
        System.assertEquals(donor.Id, giftTransaction.DonorId);
        System.assertEquals(ComgateUtil.GIFT_TRANSACTION_UNPAID, giftTransaction.Status);
        System.assertEquals(cam.Id, giftTransaction.CampaignId);
        System.assertEquals(48, giftTransaction.OriginalAmount);
        System.assertEquals(Date.today(), giftTransaction.TransactionDueDate);
        System.assertEquals('Comgate', giftTransaction.ProcessorReference);

        Payment_Reference__c paymentReferenceAssert = [SELECT Id, Gift_Transaction__c FROM Payment_Reference__c WHERE Id = :paymentReference.Id];
        System.assertEquals(giftTransaction.Id, paymentReferenceAssert.Gift_Transaction__c);
    }

    @IsTest
    public static void test_createRelatedRecords_recurringMonthly(){
        Campaign cam = ComgateTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('recurring_monthly', 48, 'card', null);

        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, cam.Id);
        paymentReference.JSON_Account__c = JSON.serialize(donor);
        paymentReference.JSON_Payment_Wrapper__c = JSON.serialize(paymentWrapper);
        paymentReference.Account__c = donor.Id;
        insert paymentReference;

        Test.startTest();
        DonationPageController.createRelatedRecords(paymentReference.Id, donor.Id);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Payment_Method__c, DonorId,
                EffectiveStartDate, Status, Comgate_Recurring__c,
                CampaignId,
        (SELECT TransactionAmount, TransactionPeriod, StartDate FROM GiftCommitmentSchedules)
        FROM GiftCommitment LIMIT 1];

        System.assertEquals(donor.Id, giftCommitmentAssert.DonorId);
        System.assertEquals('Active', giftCommitmentAssert.Status);
        System.assert(giftCommitmentAssert.Comgate_Recurring__c);
        System.assertEquals(cam.Id, giftCommitmentAssert.CampaignId);
        System.assertEquals(Date.today(), giftCommitmentAssert.EffectiveStartDate);

        GiftCommitmentSchedule giftSchedule = giftCommitmentAssert.GiftCommitmentSchedules[0];
        System.assertEquals('Monthly', giftSchedule.TransactionPeriod);
        System.assertEquals(48, giftSchedule.TransactionAmount);
        System.assertEquals(Date.today(), giftSchedule.StartDate);
    }

    @IsTest
    public static void test_justCreateRecords(){
        Bank_Account__c bankAcc = new Bank_Account__c(IBAN__c = 'CZ6508000000192000145399', Bank_Account_Number__c = '19-2000145399/0800');
        insert bankAcc;

        Campaign cam = ComgateTestFactory.getCampaign();
        cam.Bank_Account__c = bankAcc.Id;
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('recurring_monthly', 48, 'bankTransfer', null);
        Contact con = ComgateTestFactory.getContact();

        Test.startTest();
        Map<String, Object> returnMap = DonationPageController.justCreateRecords(JSON.serialize(donor), JSON.serialize(con), cam.Id, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, DonorId, Status, Comgate_Recurring__c, CampaignId
        FROM GiftCommitment LIMIT 1];

        System.assertEquals(donor.Id, giftCommitmentAssert.DonorId);
        System.assertEquals('Active', giftCommitmentAssert.Status);
        System.assert(giftCommitmentAssert.Comgate_Recurring__c);
        System.assertEquals(cam.Id, giftCommitmentAssert.CampaignId);

        System.assertEquals('19-2000145399/0800', returnMap.get('bankAccountNumber'));
        System.assertEquals('CZ6508000000192000145399', returnMap.get('iban'));
        System.assert(((String) returnMap.get('qrPayload')).startsWith('SPD*1.0*ACC:CZ6508000000192000145399'));
    }

    //Campaign without its own bank account falls back to the Bank_Account__c flagged as Default__c
    @IsTest
    public static void test_justCreateRecords_defaultBankAccount(){
        insert new Bank_Account__c(IBAN__c = 'CZ1920100000002602488698',
                Bank_Account_Number__c = '2602488698/2010', Default__c = true);

        Campaign cam = ComgateTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('oneoff', 500, 'bankTransfer', null);
        Contact con = ComgateTestFactory.getContact();

        Test.startTest();
        Map<String, Object> returnMap = DonationPageController.justCreateRecords(JSON.serialize(donor),
                JSON.serialize(con), cam.Id, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        Assert.areEqual('2602488698/2010', returnMap.get('bankAccountNumber'), 'Default bank account should be used');
        Assert.areEqual('CZ1920100000002602488698', returnMap.get('iban'), 'Default IBAN should be used');
        Assert.isTrue(((String) returnMap.get('qrPayload')).startsWith('SPD*1.0*ACC:CZ1920100000002602488698'),
                'QR payload should be built from the default IBAN');
    }

    //No default record at all must not throw - the page shows placeholders instead of erroring out
    @IsTest
    public static void test_justCreateRecords_noBankAccount(){
        Campaign cam = ComgateTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = ComgateTestFactory.getPaymentWrapper('oneoff', 500, 'bankTransfer', null);
        Contact con = ComgateTestFactory.getContact();

        Test.startTest();
        Map<String, Object> returnMap = DonationPageController.justCreateRecords(JSON.serialize(donor),
                JSON.serialize(con), cam.Id, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        Assert.areEqual('XXX-XXXXXXXX/XXX', returnMap.get('bankAccountNumber'),
                'Missing default account should fall back to the placeholder, not throw');
        Assert.areEqual('XXX-XXXXXXXX/XXX', returnMap.get('iban'),
                'Missing default account should fall back to the placeholder, not throw');
        Assert.isNotNull(returnMap.get('variableNumber'), 'Variable symbol should still be returned');
    }
}
