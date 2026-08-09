@IsTest
public with sharing class StripeMonthlyCleanupBatchTest {
    
    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Account donor = StripeTestFactory.getDonor();
        insert donor;

        GiftCommitment giftCommitment = StripeTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        List<GiftTransaction> giftTransactions = new List<GiftTransaction>();
        for(Integer i = 0; i < 3; i++){
            GiftTransaction giftTransaction = StripeTestFactory.getGiftTransaction(donor.Id, StripeUtil.GIFT_TRANSACTION_UNPAID);
            giftTransaction.GiftCommitmentId = giftCommitment.Id;
            giftTransaction.TransactionDueDate = Date.today().addMonths(-i);
            giftTransactions.add(giftTransaction);
        }
        insert giftTransactions;

        GiftCommitmentSchedule giftCommitmentSchedule = StripeTestFactory.getGiftCommitmentSchedule(giftCommitment.Id);
        insert giftCommitmentSchedule;
    }
    
    @IsTest
    public static void test_batchRun(){
        List<GiftTransaction> giftTransactions = [SELECT Id FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 3];
        for(GiftTransaction giftTransaction : giftTransactions){
            giftTransaction.TransactionDueDate = Date.today().addDays(-1);
            giftTransaction.Attempt_Counter__c = 3;
        }
        update giftTransactions;
        
        Test.startTest();
        Database.executeBatch(new StripeMonthlyCleanupBatch());
        Test.stopTest();

        GiftCommitment giftCommitment = [SELECT Id, Status, Description FROM GiftCommitment];
        Assert.areEqual('Closed', giftCommitment.Status);
    }
    
    @IsTest
    public static void test_scheduler(){
        Test.startTest();
        String jobId = System.schedule('ScheduledApexTest',
                '0 0 0 15 3 ? ' + Date.today().addYears(1).year(),
                new StripeMonthlyCleanupBatch());
        Test.stopTest();

        List<CronTrigger> jobs = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime
                FROM CronTrigger WHERE Id =: jobId
        ];

        System.assertEquals(1, jobs.size());
    }
}