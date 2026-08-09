public with sharing class StripeMonthlyCleanupBatch implements Database.Batchable<SObject>, System.Schedulable{
    public enum CLEANUP_TYPE {RECURRING_CLOSING}
    private CLEANUP_TYPE currentCleanupType;
    
    public StripeMonthlyCleanupBatch(){
        this.currentCleanupType = CLEANUP_TYPE.RECURRING_CLOSING;
    }
    
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, ' +
                '(SELECT Id, Status, Attempt_Counter__c FROM GiftTransactions ' +
                '   WHERE TransactionDueDate <= TODAY AND Status = \'Unpaid\' ORDER BY TransactionDueDate DESC LIMIT 3) ' +
                'FROM GiftCommitment ' +
                'WHERE Status = \'Active\' ' +
                'AND Stripe_Recurring__c = TRUE';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        handleLogic(scope, this.currentCleanupType);
    }
    
    public static void handleLogic(List<SObject> scope, StripeMonthlyCleanupBatch.CLEANUP_TYPE cleanupType){
        switch on cleanupType{
            when RECURRING_CLOSING{
                List<GiftCommitment> giftCommitmentForUpdate = new List<GiftCommitment>();
                for(GiftCommitment giftCommitment : (List<GiftCommitment>) scope){
                    if(giftCommitment.GiftTransactions.size() != 3) continue;

                    giftCommitment.Status = 'Closed';
                    giftCommitment.Description = '3 months not posted';
                    giftCommitmentForUpdate.add(giftCommitment);
                }
                update giftCommitmentForUpdate;
            }
        }
    }

    public void finish(Database.BatchableContext BC) {}

    public void execute(System.SchedulableContext SC) {
        Database.executeBatch(new StripeMonthlyCleanupBatch(), 50);
    }

}