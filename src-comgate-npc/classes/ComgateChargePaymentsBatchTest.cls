@IsTest
public with sharing class ComgateChargePaymentsBatchTest {

    @TestSetup
    public static void testSetup(){
        ComgateTestFactory.createComgateSettings();

        Account donor = ComgateTestFactory.getDonor();
        insert donor;

        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        giftCommitment.Comgate_Initial_Transaction_Id__c = ComgateMockTest.TRANS_ID;
        insert giftCommitment;
    }

    @IsTest
    public static void test_firstCharge_success(){
        GiftCommitment giftCommitment = [SELECT Id, DonorId FROM GiftCommitment LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(giftCommitment.DonorId, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        giftTransaction.TransactionDueDate = Date.today();
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.RecurringCreatedResponse());

        Test.startTest();
        Database.executeBatch(new ComgateChargePaymentsBatch(), 10);
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Comgate_Transaction_Id__c, Last_Attempt_Date__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_UNPAID, giftTransactionAssert.Status);
        Assert.areEqual('PENDING', giftTransactionAssert.Status__c);
        Assert.areEqual(ComgateMockTest.TRANS_ID, giftTransactionAssert.Comgate_Transaction_Id__c);
        Assert.isNotNull(giftTransactionAssert.Last_Attempt_Date__c);
    }

    @IsTest
    public static void test_firstCharge_error(){
        GiftCommitment giftCommitment = [SELECT Id, DonorId FROM GiftCommitment LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(giftCommitment.DonorId, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        giftTransaction.TransactionDueDate = Date.today();
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ErrorResponse());

        Test.startTest();
        Database.executeBatch(new ComgateChargePaymentsBatch(), 10);
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Status_Reason__c, Attempt_Counter__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_UNPAID, giftTransactionAssert.Status);
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(1, giftTransactionAssert.Attempt_Counter__c);
        Assert.isTrue(giftTransactionAssert.Status_Reason__c.contains(String.valueOf(ComgateMockTest.ERROR_CODE)));
    }

    @IsTest
    public static void test_retry_attemptLimitReached(){
        GiftCommitment giftCommitment = [SELECT Id, DonorId FROM GiftCommitment LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(giftCommitment.DonorId, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        giftTransaction.TransactionDueDate = Date.today().addDays(-10);
        giftTransaction.Status__c = 'ERROR';
        giftTransaction.Attempt_Counter__c = 2;
        giftTransaction.Last_Attempt_Date__c = Datetime.now().addDays(-8);
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ErrorResponse());

        Test.startTest();
        Database.executeBatch(new ComgateChargePaymentsBatch(), 10);
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Attempt_Counter__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_FAILED, giftTransactionAssert.Status);
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(3, giftTransactionAssert.Attempt_Counter__c);
    }

    @IsTest
    public static void test_singleGiftTransaction_constructor(){
        GiftCommitment giftCommitment = [SELECT Id, DonorId FROM GiftCommitment LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(giftCommitment.DonorId, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.RecurringCreatedResponse());

        Test.startTest();
        Database.executeBatch(new ComgateChargePaymentsBatch(giftTransaction.Id), 10);
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Comgate_Transaction_Id__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual('PENDING', giftTransactionAssert.Status__c);
        Assert.areEqual(ComgateMockTest.TRANS_ID, giftTransactionAssert.Comgate_Transaction_Id__c);
    }

    @IsTest
    public static void test_schedulable(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.RecurringCreatedResponse());

        Test.startTest();
        String jobId = System.schedule('ComgateChargePaymentsBatchTest', '0 0 23 * * ?', new ComgateChargePaymentsBatch());
        Test.stopTest();

        Assert.isNotNull(jobId);
    }
}
