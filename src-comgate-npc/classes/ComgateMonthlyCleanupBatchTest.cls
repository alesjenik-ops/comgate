@IsTest
public with sharing class ComgateMonthlyCleanupBatchTest {

    @TestSetup
    public static void testSetup(){
        ComgateTestFactory.createComgateSettings();
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
    }

    @IsTest
    public static void test_recurringClosing_threeUnpaid(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        List<GiftTransaction> giftTransactions = new List<GiftTransaction>();
        for(Integer i = 0; i < 3; i++){
            GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
            giftTransaction.GiftCommitmentId = giftCommitment.Id;
            giftTransaction.TransactionDueDate = Date.today().addMonths(-i);
            giftTransactions.add(giftTransaction);
        }
        insert giftTransactions;

        Test.startTest();
        Database.executeBatch(new ComgateMonthlyCleanupBatch(), 50);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Status, Description FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);
        Assert.areEqual('3 months not posted', giftCommitmentAssert.Description);
    }

    @IsTest
    public static void test_recurringClosing_lessThanThreeUnpaid(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        List<GiftTransaction> giftTransactions = new List<GiftTransaction>();
        for(Integer i = 0; i < 2; i++){
            GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
            giftTransaction.GiftCommitmentId = giftCommitment.Id;
            giftTransaction.TransactionDueDate = Date.today().addMonths(-i);
            giftTransactions.add(giftTransaction);
        }
        insert giftTransactions;

        Test.startTest();
        Database.executeBatch(new ComgateMonthlyCleanupBatch(), 50);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Status FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.areEqual('Active', giftCommitmentAssert.Status);
    }

    @IsTest
    public static void test_schedulable(){
        Test.startTest();
        String jobId = System.schedule('ComgateMonthlyCleanupBatchTest', '0 0 23 * * ?', new ComgateMonthlyCleanupBatch());
        Test.stopTest();

        Assert.isNotNull(jobId);
    }
}
