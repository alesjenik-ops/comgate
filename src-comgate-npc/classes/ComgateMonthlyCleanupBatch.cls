public with sharing class ComgateMonthlyCleanupBatch implements Database.Batchable<SObject>, System.Schedulable{
    public enum CLEANUP_TYPE {RECURRING_CLOSING}
    private CLEANUP_TYPE currentCleanupType;

    public ComgateMonthlyCleanupBatch(){
        this.currentCleanupType = CLEANUP_TYPE.RECURRING_CLOSING;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String query = 'SELECT Id, ' +
                '(SELECT Id, Status, Attempt_Counter__c FROM GiftTransactions ' +
                '   WHERE TransactionDueDate <= TODAY ORDER BY TransactionDueDate DESC LIMIT 3) ' +
                'FROM GiftCommitment ' +
                'WHERE Status = \'Active\' ' +
                'AND Comgate_Recurring__c = TRUE';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<SObject> scope) {
        handleLogic(scope, this.currentCleanupType);
    }

    //Splatky, ktere se nepodarilo vybrat: Unpaid (ceka / zamitnuto bankou az ve webhooku)
    //i Failed (Comgate platbu odmitl hned a vycerpaly se pokusy).
    private static final Set<String> NOT_POSTED_STATUSES = new Set<String>{
            ComgateUtil.GIFT_TRANSACTION_UNPAID, ComgateUtil.GIFT_TRANSACTION_FAILED
    };

    public static void handleLogic(List<SObject> scope, ComgateMonthlyCleanupBatch.CLEANUP_TYPE cleanupType){
        switch on cleanupType{
            when RECURRING_CLOSING{
                List<GiftCommitment> giftCommitmentForUpdate = new List<GiftCommitment>();
                for(GiftCommitment giftCommitment : (List<GiftCommitment>) scope){
                    //Zavira se, kdyz zadna z poslednich tri splatnych splatek neprosla
                    if(giftCommitment.GiftTransactions.size() != 3) continue;
                    Boolean allNotPosted = true;
                    for(GiftTransaction giftTransaction : giftCommitment.GiftTransactions){
                        if(!NOT_POSTED_STATUSES.contains(giftTransaction.Status)) allNotPosted = false;
                    }
                    if(!allNotPosted) continue;

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
        Database.executeBatch(new ComgateMonthlyCleanupBatch(), 50);
    }

}