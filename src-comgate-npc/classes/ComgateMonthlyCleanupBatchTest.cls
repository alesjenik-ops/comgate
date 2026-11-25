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
    public static void test_recurringClosing_failedCountsAsNotPosted(){
        GiftCommitment giftCommitment = createCommitmentWithStatuses(new List<String>{
                ComgateUtil.GIFT_TRANSACTION_FAILED, ComgateUtil.GIFT_TRANSACTION_UNPAID, ComgateUtil.GIFT_TRANSACTION_FAILED});

        Test.startTest();
        Database.executeBatch(new ComgateMonthlyCleanupBatch(), 50);
        Test.stopTest();

        Assert.areEqual('Closed', [SELECT Status FROM GiftCommitment WHERE Id = :giftCommitment.Id].Status);
    }

    @IsTest
    public static void test_recurringClosing_paidAmongLastThreeKeepsActive(){
        GiftCommitment giftCommitment = createCommitmentWithStatuses(new List<String>{
                ComgateUtil.GIFT_TRANSACTION_FAILED, ComgateUtil.GIFT_TRANSACTION_PAID, ComgateUtil.GIFT_TRANSACTION_UNPAID});

        Test.startTest();
        Database.executeBatch(new ComgateMonthlyCleanupBatch(), 50);
        Test.stopTest();

        Assert.areEqual('Active', [SELECT Status FROM GiftCommitment WHERE Id = :giftCommitment.Id].Status);
    }

    //Splatky po mesicich zpet od dneska, statuses[0] je nejnovejsi
    private static GiftCommitment createCommitmentWithStatuses(List<String> statuses){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        List<GiftTransaction> giftTransactions = new List<GiftTransaction>();
        for(Integer i = 0; i < statuses.size(); i++){
            GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, statuses[i]);
            giftTransaction.GiftCommitmentId = giftCommitment.Id;
            giftTransaction.TransactionDueDate = Date.today().addMonths(-i);
            //Zaplacena splatka musi mit datum platby (validace NPC)
            if(statuses[i] == ComgateUtil.GIFT_TRANSACTION_PAID) giftTransaction.TransactionDate = giftTransaction.TransactionDueDate;
            giftTransactions.add(giftTransaction);
        }
        insert giftTransactions;
        return giftCommitment;
    }

    @IsTest
    public static void test_schedulable(){
        Test.startTest();
        String jobId = System.schedule('ComgateMonthlyCleanupBatchTest', '0 0 23 * * ?', new ComgateMonthlyCleanupBatch());
        Test.stopTest();

        Assert.isNotNull(jobId);
    }
}