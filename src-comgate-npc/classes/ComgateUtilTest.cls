@IsTest
public with sharing class ComgateUtilTest {

    @IsTest
    public static void test_convertComgatePaymentMethod(){
        Assert.areEqual('Credit Card', ComgateUtil.convertComgatePaymentMethod('CARD_CZ_COMGATE'));
        Assert.areEqual('Online Bank', ComgateUtil.convertComgatePaymentMethod('BANK_CZ_KB'));
        Assert.areEqual('Google Pay', ComgateUtil.convertComgatePaymentMethod('GPAY'));
        Assert.areEqual('Apple Pay', ComgateUtil.convertComgatePaymentMethod('APPLEPAY'));
        Assert.areEqual('Bank Transfer', ComgateUtil.convertComgatePaymentMethod('TRANSFER'));
        Assert.areEqual('LATER_TWISTO', ComgateUtil.convertComgatePaymentMethod('LATER_TWISTO'));
        Assert.isNull(ComgateUtil.convertComgatePaymentMethod(null));
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
}
