public without sharing class ComgateChargePaymentsBatch implements Database.Batchable<SObject>, System.Schedulable, Database.AllowsCallouts {
    private final Id giftTransactionId;

    @TestVisible private static final String ERROR_RECURRING_CHARGE_FAILED = 'Recurring charge request failed!';

    public ComgateChargePaymentsBatch() {
    }

    public ComgateChargePaymentsBatch(Id giftTransactionId) {
        this.giftTransactionId = giftTransactionId;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Decimal attemptCounterLimit = ComgateUtil.comgateSettings.Attempt_Limit__c;
        Date lastAttemptDate = Date.today().addDays(-ComgateUtil.comgateSettings.Attempt_Delay__c.intValue()) + 1;
        Boolean nextChargingDateToday = isChargingDateToday();

        String query = 'SELECT Id, GiftCommitmentId, Status__c, OriginalAmount, Last_Attempt_Date__c, ' +
                ' TransactionDueDate, DonorId, Attempt_Counter__c, CurrencyIsoCode, Comgate_Transaction_Id__c, ' +
                ' Status_Reason__c, GiftCommitment.Comgate_Initial_Transaction_Id__c, ' +
                ' Campaign.Comgate_Bank_Account__c ' +
                ' FROM GiftTransaction ';
        if (giftTransactionId == null) {
            query += ' WHERE Status = \'Unpaid\' AND Status__c != \'PENDING\'' +
                    '   AND (GiftCommitment.Comgate_Authorized__c = TRUE ' +
                    '   AND GiftCommitment.Status = \'Active\') ' +
                    ' AND ((TransactionDueDate < TODAY ' +
                    '    AND Status__c != null ' +
                    '    AND (Attempt_Counter__c < :attemptCounterLimit OR Attempt_Counter__c = null) ' +
                    '    AND (Last_Attempt_Date__c = NULL OR Last_Attempt_Date__c < :lastAttemptDate)) ' +
                    getRecurringQueryPart(nextChargingDateToday) +
                    ')';
        }
        if (giftTransactionId != null) query += ' WHERE Id = :giftTransactionId';
        return Database.getQueryLocator(query);
    }

    private static String getRecurringQueryPart(Boolean nextChargingDateToday) {
        if (nextChargingDateToday) {
            return 'OR (GiftCommitment.Comgate_Recurring__c = TRUE ' +
                    '   AND TransactionDueDate <= TODAY  ' +
                    '   AND Last_Attempt_Date__c = NULL ' +
                    '   AND Status__c = NULL)';
        }
        return '';
    }


    private static Boolean isChargingDateToday() {
        return Date.today().day() == ComgateUtil.comgateSettings.Day_Of_Charging__c
                || ComgateUtil.comgateSettings.Day_Of_Charging__c == 0
                || ComgateUtil.comgateSettings.Day_Of_Charging__c == null;
    }

    public void execute(Database.BatchableContext BC, List<GiftTransaction> scope) {
        processGiftTransactions(scope);
    }

    public void processGiftTransactions(List<GiftTransaction> scope) {
        List<GiftTransaction> giftTransactionForUpdate = new List<GiftTransaction>();
        for(GiftTransaction giftTransaction : scope){
            ComgateRecurringRequestWrapper requestWrapper = new ComgateRecurringRequestWrapper(giftTransaction);
            ComgatePaymentResponseWrapper responseWrapper = ComgateService.getRecurringPayment(requestWrapper);
            if(responseWrapper == null || (responseWrapper.code != null && responseWrapper.code != 0)){
                ComgateUtil.setDonationStatus(giftTransaction, 'ERROR',
                        responseWrapper == null ? ERROR_RECURRING_CHARGE_FAILED : responseWrapper.code + ' ' + responseWrapper.message,
                        giftTransaction.Attempt_Counter__c);
                if(giftTransaction.Attempt_Counter__c >= ComgateUtil.comgateSettings.Attempt_Limit__c) {
                    giftTransaction.Status = ComgateUtil.GIFT_TRANSACTION_FAILED;
                }
            } else {
                giftTransaction.Status__c = 'PENDING';
                giftTransaction.Comgate_Transaction_Id__c = responseWrapper.transId;
                giftTransaction.Last_Attempt_Date__c = Datetime.now();
            }
            giftTransactionForUpdate.add(giftTransaction);
        }
        update giftTransactionForUpdate;
    }

    public void finish(Database.BatchableContext BC) {
        if(ComgateUtil.comgateSettings.Day_Of_Charging__c == 0){
            if(Date.today().day() != Date.today().addMonths(1).toStartOfMonth().addDays(-1).day()) return;
        }
        if(!Test.isRunningTest() && isChargingDateToday() && ComgateUtil.checkIfAlreadyScheduled('ComgateMonthlyCleanupBatch')) System.scheduleBatch(new ComgateMonthlyCleanupBatch(),'ComgateMonthlyCleanupBatch',60, 10);
    }

    public void execute(System.SchedulableContext SC) {
        Database.executeBatch(new ComgateChargePaymentsBatch(), 10);
    }
}
