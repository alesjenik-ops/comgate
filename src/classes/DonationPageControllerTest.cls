@IsTest
public with sharing class DonationPageControllerTest {

    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Stripe_Settings__c settings = Stripe_Settings__c.getOrgDefaults();
        settings.Day_Of_Charging__c = 0;
        update settings;

        Account donor = StripeTestFactory.getDonor();
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
    public static void test_getFieldSetWrapper_existingContact(){
        FieldSet donationFieldSet = Account.SObjectType.getDescribe().fieldSets.getMap().get('DonationPage_Default');
        Id contactId = [SELECT Id FROM Contact LIMIT 1].Id;
        if(donationFieldSet == null) return;

        Test.startTest();
        String returnJSON = DonationPageController.getFieldSetWrapper(donationFieldSet?.getName(), contactId, null);
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        List<Object> wrappers = (List<Object>) returnMap.get('fieldSetWrapper');
        Object contact = (Object) returnMap.get('contact');

        System.assert(wrappers != null);
        System.assertEquals(donationFieldSet.fields.size(), wrappers.size());
        System.assert(contact != null);
    }

    @IsTest
    public static void test_getReferenceId_newContact(){
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();
        Account donor = StripeTestFactory.getDonor();
        donor.Stripe_Customer_Id__c = StripeMockTest.CUSTOMER_ID;
        Contact con = StripeTestFactory.getContact();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');
        String customerReference = (String) returnMap.get('stripeCustomerReference');

        Account donorAssert = [SELECT Id, PersonLeadSource, Stripe_Customer_Id__c FROM Account WHERE PersonEmail =: donor.PersonEmail];
        System.assertEquals(2, [SELECT Id FROM Contact].size());
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals(customerReference, donorAssert.Stripe_Customer_Id__c);
        System.assertEquals('Donation Page', donorAssert.PersonLeadSource);
    }

    @IsTest
    public static void test_getReferenceId_existingContact(){
        Account donor = [SELECT Id, FirstName, LastName, PersonEmail, Stripe_Customer_Id__c FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();
        Contact con = StripeTestFactory.getContact();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');
        String customerReference = (String) returnMap.get('stripeCustomerReference');

        Account donorAssert = [SELECT Id, PersonLeadSource, Stripe_Customer_Id__c FROM Account WHERE PersonEmail =: donor.PersonEmail];
        System.assertEquals(1, [SELECT Id FROM Contact].size());
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals(customerReference, donorAssert.Stripe_Customer_Id__c);
        System.assertEquals(null, donorAssert.PersonLeadSource);
    }
    

    @IsTest
    public static void test_processDonation_createSession(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.CreateCheckoutSessionResponse());

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail, Stripe_Customer_Id__c FROM Account LIMIT 1];
        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, null);
        insert paymentReference;
        DonationPagePaymentWrapper paymentWrapper = StripeTestFactory.getPaymentWrapper('oneoff', 48, 'card', null);
        paymentWrapper.allowedPaymentMethods = new List<String>{'card'};

        Test.startTest();
        StripeCheckoutSessionResponseWrapper response = DonationPageController.getPaymentConfiguration(paymentReference.Id, donor.Id, JSON.serialize(donor), JSON.serialize(paymentWrapper));
        Test.stopTest();

        System.assertEquals(1000, response.amount);
        System.assertEquals(StripeMockTest.CHECKOUT_SESSION_ID, response.id);
    }

    @IsTest
    public static void test_createRelatedRecords_oneOff(){
        Campaign cam = StripeTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = StripeTestFactory.getPaymentWrapper('oneoff', 48, 'card', null);

        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, cam.Id);
        paymentReference.JSON_Account__c = JSON.serialize(donor);
        paymentReference.JSON_Payment_Wrapper__c = JSON.serialize(paymentWrapper);
        paymentReference.Account__c = donor.Id;
        insert paymentReference;

        Test.startTest();
        DonationPageController.createRelatedRecords(paymentReference.Id, donor.Id);
        Test.stopTest();

        GiftTransaction giftTransaction = [SELECT Id, DonorId, Payment_Method__c, Status, CampaignId,
                OriginalAmount, TransactionDueDate FROM GiftTransaction LIMIT 1];
        System.assertEquals(donor.Id, giftTransaction.DonorId);
        System.assertEquals(StripeUtil.GIFT_TRANSACTION_UNPAID, giftTransaction.Status);
        System.assertEquals(cam.Id, giftTransaction.CampaignId);
        System.assertEquals(48, giftTransaction.OriginalAmount);
        System.assertEquals(Date.today(), giftTransaction.TransactionDueDate);

    }

    @IsTest
    public static void test_createRelatedRecords_recurringMonthly(){
        Campaign cam = StripeTestFactory.getCampaign();
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = StripeTestFactory.getPaymentWrapper('recurring_monthly', 48, 'paypal', null);

        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, cam.Id);
        paymentReference.JSON_Account__c = JSON.serialize(donor);
        paymentReference.JSON_Payment_Wrapper__c = JSON.serialize(paymentWrapper);
        paymentReference.Account__c = donor.Id;
        insert paymentReference;

        Test.startTest();
        DonationPageController.createRelatedRecords(paymentReference.Id, donor.Id);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Payment_Method__c, DonorId,
                EffectiveStartDate, Status, Stripe_Recurring__c,
                CampaignId,
        (SELECT TransactionAmount, TransactionPeriod, StartDate FROM GiftCommitmentSchedules)
        FROM GiftCommitment LIMIT 1];

        System.assertEquals(donor.Id, giftCommitmentAssert.DonorId);
        System.assertEquals('Active', giftCommitmentAssert.Status);
        System.assert(giftCommitmentAssert.Stripe_Recurring__c);
        System.assertEquals(cam.Id, giftCommitmentAssert.CampaignId);
        System.assertEquals(Date.today(), giftCommitmentAssert.EffectiveStartDate);

        GiftCommitmentSchedule giftSchedule = giftCommitmentAssert.GiftCommitmentSchedules[0];
        System.assertEquals('Monthly', giftSchedule.TransactionPeriod);
        System.assertEquals(48, giftSchedule.TransactionAmount);
        System.assertEquals(Date.today(), giftSchedule.StartDate);
    }

    @IsTest
    public static void test_getReferenceId_personAccount_new(){
        Account donor = StripeTestFactory.getDonor();
        Contact con = StripeTestFactory.getContact();
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();

        Test.startTest();
        String returnJSON = DonationPageController.getReferenceId(
            JSON.serialize(donor), JSON.serialize(con), null, JSON.serialize(paymentWrapper), true
        );
        Test.stopTest();

        Map<String, Object> returnMap = (Map<String, Object>) JSON.deserializeUntyped(returnJSON);
        String shopperReference = (String) returnMap.get('shopperReference');
        String paymentReference = (String) returnMap.get('paymentReference');

        Account donorAssert = [SELECT Id, PersonLeadSource, Stripe_Customer_Id__c FROM Account WHERE PersonEmail =: donor.PersonEmail];
        System.assertEquals(paymentReference, [SELECT Id FROM Payment_Reference__c].Id);
        System.assertEquals(shopperReference, donorAssert.Id);
        System.assertEquals('Donation Page', donorAssert.PersonLeadSource);
    }

    @IsTest
    public static void test_getReferenceId_personAccount_existing(){
        Account donor = [SELECT Id, FirstName, LastName, PersonEmail, Stripe_Customer_Id__c FROM Account LIMIT 1];
        Contact con = StripeTestFactory.getContact();
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
        Contact con = StripeTestFactory.getContact();
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
    public static void test_justCreateRecords(){
        Bank_Account__c bankAcc = new Bank_Account__c(IBAN__c = 'TEST', Bank_Account_Number__c = 'TEST');
        insert bankAcc;

        Campaign cam = StripeTestFactory.getCampaign();
        cam.Bank_Account__c = bankAcc.Id;
        insert cam;

        Account donor = [SELECT Id, FirstName, LastName, PersonEmail FROM Account LIMIT 1];
        DonationPagePaymentWrapper paymentWrapper = StripeTestFactory.getPaymentWrapper('recurring_monthly', 48, 'paypal', null);
        Contact con = StripeTestFactory.getContact();

        Test.startTest();
        DonationPageController.justCreateRecords(JSON.serialize(donor), JSON.serialize(con), cam.Id, JSON.serialize(paymentWrapper), true);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Payment_Method__c, DonorId,
                EffectiveStartDate, Status, Stripe_Recurring__c,
                CampaignId,
        (SELECT TransactionAmount, TransactionPeriod, StartDate FROM GiftCommitmentSchedules)
        FROM GiftCommitment LIMIT 1];

        System.assertEquals(donor.Id, giftCommitmentAssert.DonorId);
        System.assertEquals('Active', giftCommitmentAssert.Status);
        System.assert(giftCommitmentAssert.Stripe_Recurring__c);
        System.assertEquals(cam.Id, giftCommitmentAssert.CampaignId);
        System.assertEquals(Date.today(), giftCommitmentAssert.EffectiveStartDate);

        GiftCommitmentSchedule giftSchedule = giftCommitmentAssert.GiftCommitmentSchedules[0];
        System.assertEquals('Monthly', giftSchedule.TransactionPeriod);
        System.assertEquals(48, giftSchedule.TransactionAmount);
        System.assertEquals(Date.today(), giftSchedule.StartDate);
    }
}