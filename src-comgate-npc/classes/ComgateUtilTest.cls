@IsTest
public with sharing class ComgateUtilTest {

    @IsTest
    public static void test_convertComgatePaymentMethod(){
        Assert.areEqual('Credit Card', ComgateUtil.convertComgatePaymentMethod('CARD_CZ_COMGATE'));
        Assert.areEqual('Online Bank', ComgateUtil.convertComgatePaymentMethod('BANK_CZ_KB'));
        Assert.areEqual('Bank Transfer', ComgateUtil.convertComgatePaymentMethod('TRANSFER'));
    }

    @IsTest
    public static void test_convertComgatePaymentMethod_wallets(){
        //GOOGLEPAY is the code Comgate actually sends in the webhook; GPAY kept for backwards compatibility
        Assert.areEqual('Google Pay', ComgateUtil.convertComgatePaymentMethod('GOOGLEPAY'));
        Assert.areEqual('Google Pay', ComgateUtil.convertComgatePaymentMethod('GOOGLEPAY_REDIRECT'));
        Assert.areEqual('Google Pay', ComgateUtil.convertComgatePaymentMethod('GPAY'));
        Assert.areEqual('Apple Pay', ComgateUtil.convertComgatePaymentMethod('APPLEPAY'));
        Assert.areEqual('Apple Pay', ComgateUtil.convertComgatePaymentMethod('APPLEPAY_REDIRECT'));
    }

    @IsTest
    public static void test_convertComgatePaymentMethod_unknownStaysNull(){
        //Payment_Method__c is a restricted picklist - an unmapped code must not get through,
        //otherwise the DML fails with INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST and the webhook answers 500
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod('LATER_TWISTO'));
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod('PRSMS'));
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod(null));
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod(''));
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod('   '));
    }

    @IsTest
    public static void test_isIdValid(){
        Account donor = ComgateTestFactory.getDonor();
        insert donor;

        Assert.isTrue(ComgateUtil.isIdValid(donor.Id));
        Assert.isFalse(ComgateUtil.isIdValid('not-an-id'));
        Assert.isFalse(ComgateUtil.isIdValid(null));
    }

    @IsTest
    public static void test_comgateSettings(){
        ComgateTestFactory.createComgateSettings();

        Assert.areEqual(3, ComgateUtil.comgateSettings.Attempt_Limit__c);
        Assert.areEqual(7, ComgateUtil.comgateSettings.Attempt_Delay__c);
    }

    @IsTest
    public static void test_setDonationStatus_error(){
        GiftTransaction giftTransaction = new GiftTransaction();

        Test.startTest();
        ComgateUtil.setDonationStatus(giftTransaction, 'ERROR', 'Something failed', 2);
        Test.stopTest();

        Assert.areEqual('ERROR', giftTransaction.Status__c);
        Assert.areEqual('Something failed', giftTransaction.Status_Reason__c);
        Assert.areEqual(3, giftTransaction.Attempt_Counter__c);
        Assert.isNotNull(giftTransaction.Last_Attempt_Date__c);
    }

    @IsTest
    public static void test_setDonationStatus_nonError(){
        GiftTransaction giftTransaction = new GiftTransaction();

        Test.startTest();
        ComgateUtil.setDonationStatus(giftTransaction, 'PENDING', null, 2);
        Test.stopTest();

        Assert.areEqual('PENDING', giftTransaction.Status__c);
        Assert.isNull(giftTransaction.Attempt_Counter__c);
    }

    @IsTest
    public static void test_checkIfAlreadyScheduled(){
        Assert.isTrue(ComgateUtil.checkIfAlreadyScheduled('ComgateUtilTestJob'));

        System.schedule('ComgateUtilTestJob', '0 0 23 * * ?', new ComgateChargePaymentsBatch());
        Assert.isFalse(ComgateUtil.checkIfAlreadyScheduled('ComgateUtilTestJob'));
    }

    @IsTest
    public static void test_runningInASandbox(){
        Assert.isNotNull(ComgateUtil.runningInASandbox);
    }

    @IsTest
    public static void test_isTestPayment(){
        ComgateUtil.runningInASandbox = false;
        ComgateUtil.comgateSettings = new Comgate_Settings__c(Test_Mode__c = false);
        Assert.isFalse(ComgateUtil.isTestPayment);

        ComgateUtil.comgateSettings = new Comgate_Settings__c(Test_Mode__c = true);
        Assert.isTrue(ComgateUtil.isTestPayment);

        ComgateUtil.runningInASandbox = true;
        ComgateUtil.comgateSettings = new Comgate_Settings__c(Test_Mode__c = false);
        Assert.isTrue(ComgateUtil.isTestPayment);
    }
}
