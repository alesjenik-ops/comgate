/**
 * Created by LukášGregora on 09/12/2023.
 */

public without sharing class StripeChargePaymentsBatch implements Database.Batchable<SObject>, System.Schedulable, Database.AllowsCallouts {
    private Id giftTransactionId;
    private Map<Id, GiftTransaction> giftTransactionForUpdate = new Map<Id, GiftTransaction>();
    private Map<Id, Payment_Log__c> paymentLogUpdate = new Map<Id, Payment_Log__c>();

    @TestVisible private static final String ERROR_MISSING_SESSION_AUTHORIZATION = 'Missing session authorization log in the Payment Log';
    @TestVisible private static final String ERROR_MISSING_SETUP_INTENT = 'Missing setup intent!';
    @TestVisible private static final String ERROR_CAPTURE_FAILED = 'Capture request failed!';
    @TestVisible private static final String ERROR_PAYMENT_INTENT_CREATE = 'Payment intent cannot be created!';
    @TestVisible private static final String ERROR_SETUP_INTENT_GET = 'Setup intent cannot be fetched!';
    @TestVisible private static final String ERROR_PAYMENT_METHOD_GET = 'Payment method cannot be fetched!';
    
    public StripeChargePaymentsBatch() {
    }

    public StripeChargePaymentsBatch(Id giftTransactionId) {
        this.giftTransactionId = giftTransactionId;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Decimal attemptCounterLimit = StripeUtil.stripeSettings.Attempt_Limit__c;
        Date lastAttemptDate = Date.today().addDays(-StripeUtil.stripeSettings.Attempt_Delay__c.intValue()) + 1;
        Boolean nextChargingDateToday = isChargingDateToday();

        String query = 'SELECT Id, GiftCommitmentId, Status__c, OriginalAmount, Last_Attempt_Date__c, ' +
                ' TransactionDueDate, DonorId, Attempt_Counter__c, Stripe_Payment_Intent__c,' +
                ' Donor.Stripe_Customer_Id__c, Payment_Method__c, ' +
                ' GiftCommitment.Payment_Method__c ' +
                ' FROM GiftTransaction ';
        if (giftTransactionId == null) {
            query += ' WHERE Status = \'Unpaid\' AND Status__c != \'PENDING\'' +
                    '   AND (GiftCommitment.Stripe_Authorized__c = TRUE ' +
                    '   AND GiftCommitment.Status = \'Active\') ' +
                    ' AND ((TransactionDueDate < TODAY ' +
                    '    AND Status__c != null ' +
                    '    AND (Attempt_Counter__c < :attemptCounterLimit OR Attempt_Counter__c = null) ' +
                    '    AND (Last_Attempt_Date__c = NULL OR Last_Attempt_Date__c < :lastAttemptDate)) ' +
                    getRecurringQueryPart(nextChargingDateToday) +
                    ')';
        }
        if (giftTransactionId != null) query += ' WHERE Id = :oppId';
        return Database.getQueryLocator(query);
    }

    public void execute(Database.BatchableContext BC, List<GiftTransaction> scope) {
        processGiftTransactions(scope);
    }

    public void processGiftTransactions(List<GiftTransaction> scope) {
        Map<Id, Payment_Log__c> paymentLogMap = getPaymentLogs(scope);
        for (GiftTransaction giftTransaction : scope) {
            Payment_Log__c paymentLog = giftTransaction.GiftCommitmentId != null ? paymentLogMap.get(giftTransaction.GiftCommitmentId) : paymentLogMap.get(giftTransaction.Id);
            if (paymentLog == null) {
                StripeUtil.setDonationStatus(giftTransaction, 'ERROR', ERROR_MISSING_SESSION_AUTHORIZATION, giftTransaction.Attempt_Counter__c);
                giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
                continue;
            }
            processGiftTransaction(giftTransaction, paymentLog);
        }
        update giftTransactionForUpdate.values();
        update paymentLogUpdate.values();
    }
    
    private void processGiftTransaction(GiftTransaction giftTransaction, Payment_Log__c paymentLog){
        if (paymentLog.Setup_Intent__c == null){
            StripeUtil.setDonationStatus(giftTransaction, 'ERROR', ERROR_MISSING_SETUP_INTENT, giftTransaction.Attempt_Counter__c);
            giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
        }  else if (paymentLog.Payment_Method_Id__c != null && giftTransaction.Payment_Method__c == null){
            StripePaymentMethodResponseWrapper paymentMethodResponse = StripeService.getPaymentMethod(paymentLog.Payment_Method_Id__c);
            if (paymentMethodResponse == null || paymentMethodResponse.error != null){
                StripeUtil.setDonationStatus(giftTransaction, 'ERROR',
                        StripeUtil.getOneMessage(paymentMethodResponse?.error?.message, ERROR_PAYMENT_METHOD_GET),
                        giftTransaction.Attempt_Counter__c);
                giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
                return;
            }

            giftTransaction.Payment_Method__c = StripeUtil.convertStripePaymentMethod(paymentMethodResponse.type);
            giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
            processGiftTransaction(giftTransaction, paymentLog);
        } else if (paymentLog.Payment_Method_Id__c != null){
            StripePaymentIntentRequestWrapper paymentIntentRequest = new StripePaymentIntentRequestWrapper(
                    giftTransaction.OriginalAmount,
                    StripeUtil.DEFAULT_CURRENCY,
                    paymentLog.Payment_Method_Id__c,
                    paymentLog.Payment_Method__c != null ? paymentLog.Payment_Method__c : giftTransaction.Payment_Method__c,
                    giftTransaction.Donor.Stripe_Customer_Id__c,
                    giftTransaction.Id,
                    paymentLog.Payment_Reference__c,
                    paymentLog.Payment_Reference__r.Radar_Session_Id__c);
            StripePaymentIntentResponseWrapper paymentIntentResponse = StripeService.createPaymentIntent(paymentIntentRequest);
            if (paymentIntentResponse == null || paymentIntentResponse.error != null){
                StripeUtil.setDonationStatus(giftTransaction, 'ERROR',
                        StripeUtil.getOneMessage(paymentIntentResponse?.error?.message, ERROR_PAYMENT_INTENT_CREATE),
                        giftTransaction.Attempt_Counter__c);
                giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
                return;
            }

            giftTransaction.Stripe_Payment_Intent__c = paymentIntentResponse.id;
            if(giftTransaction.Payment_Method__c == 'SEPA Direct Debit' || giftTransaction.GiftCommitment?.Payment_Method__c == 'SEPA Direct Debit') giftTransaction.Status__c = 'PENDING';
            giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
        } else if (paymentLog.Setup_Intent__c != null){
            StripeSetupIntentResponseWrapper setupIntent = StripeService.getSetupIntent(paymentLog.Setup_Intent__c);
            if (setupIntent == null || setupIntent.error != null){
                StripeUtil.setDonationStatus(giftTransaction, 'ERROR',
                        StripeUtil.getOneMessage(setupIntent?.error?.message, ERROR_SETUP_INTENT_GET),
                        giftTransaction.Attempt_Counter__c);
                giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
                return;
            }
            paymentLog.Payment_Method_Id__c = setupIntent.payment_method;
            paymentLogUpdate.put(paymentLog.Id, paymentLog);
            processGiftTransaction(giftTransaction, paymentLog);
        } 
    }


    private static Map<Id, Payment_Log__c> getPaymentLogs(List<GiftTransaction> scope) {
        Map<Id, Payment_Log__c> recurrentPaymentLogMap = new Map<Id, Payment_Log__c>();
        for (GiftTransaction giftTransaction : scope) {
            if (giftTransaction.GiftCommitmentId != null) recurrentPaymentLogMap.put(giftTransaction.GiftCommitmentId, null);
            recurrentPaymentLogMap.put(giftTransaction.Id, null);
        }

        for (Payment_Log__c paymentLog : [
                SELECT Id,
                        Gift_Commitment__c, Currency__c, Gift_Transaction__c, Payment_Reference__c,
                        Payment_Reference__r.Radar_Session_Id__c,
                        Payment_Reference__r.Gift_Commitment__c, Payment_Reference__r.Gift_Transaction__c,
                        Setup_Intent__c, Payment_Method_Id__c, Payment_Method__c
                FROM Payment_Log__c
                WHERE (Gift_Commitment__c IN :recurrentPaymentLogMap.keySet()
                OR Payment_Reference__r.Gift_Commitment__c IN :recurrentPaymentLogMap.keySet()
                OR Gift_Transaction__c IN :recurrentPaymentLogMap.keySet()
                OR Payment_Reference__r.Gift_Transaction__c IN :recurrentPaymentLogMap.keySet())
                AND Event_Code__c = 'checkout.session.completed'
                ORDER BY CreatedDate ASC
        ]) {
            if (paymentLog.Gift_Commitment__c != null) recurrentPaymentLogMap.put(paymentLog.Gift_Commitment__c, paymentLog);
            if (paymentLog.Gift_Transaction__c != null) recurrentPaymentLogMap.put(paymentLog.Gift_Transaction__c, paymentLog);
            if (paymentLog.Payment_Reference__r?.Gift_Commitment__c != null) recurrentPaymentLogMap.put(paymentLog.Payment_Reference__r?.Gift_Commitment__c, paymentLog);
            if (paymentLog.Payment_Reference__r?.Gift_Transaction__c != null) recurrentPaymentLogMap.put(paymentLog.Payment_Reference__r?.Gift_Transaction__c, paymentLog);
        }
        return recurrentPaymentLogMap;
    }
    

    public void finish(Database.BatchableContext BC) {
        if(StripeUtil.stripeSettings.Day_Of_Charging__c == 0){
            if(Date.today().day() != Date.today().addMonths(1).toStartOfMonth().addDays(-1).day()) return;
        }
        if(!Test.isRunningTest() && isChargingDateToday() && !StripeUtil.checkIfAlreadyScheduled('StripeMonthlyCleanupBatch')) System.scheduleBatch(new StripeMonthlyCleanupBatch(),'StripeMonthlyCleanupBatch',60, 10);
    }

    private static String getRecurringQueryPart(Boolean nextChargingDateToday) {
        if (nextChargingDateToday) {
            return 'OR (GiftCommitment.Stripe_Recurring__c = TRUE ' +
                    '   AND TransactionDueDate <= TODAY  ' +
                    '   AND Last_Attempt_Date__c = NULL ' +
                    '   AND Status__c = NULL)';
        }
        return '';
    }

    private static Boolean isChargingDateToday() {
        return Date.today().day() == StripeUtil.stripeSettings.Day_Of_Charging__c
                || StripeUtil.stripeSettings.Day_Of_Charging__c == 0
                || StripeUtil.stripeSettings.Day_Of_Charging__c == null;
    }

    public static void fetchPaymentsMethodIds(Set<Id> paymentReferenceIds) {
        if (Trigger.isExecuting) {
            System.enqueueJob(new FetchPaymentMethodsQueueable(paymentReferenceIds));
            return;
        }
        List<Payment_Reference__c> paymentReferences = [
                SELECT Id, (
                        SELECT Id, Setup_Intent__c, Payment_Method__c
                        FROM Payment_Log__r
                        WHERE Event_Code__c = 'checkout.session.completed'
                        AND Payment_Method_Id__c = NULL AND Setup_Intent__c != NULL
                        ORDER BY CreatedDate ASC
                        LIMIT 1
                ),
                        Gift_Transaction__r.OriginalAmount,
                        Gift_Commitment__r.Payment_Method__c,
                        Account__r.Stripe_Customer_Id__c,
                        Gift_Commitment__c
                FROM Payment_Reference__c
                WHERE Id IN :paymentReferenceIds AND Gift_Commitment__c != NULL
        ];
        Map<Id, Payment_Log__c> logsForUpdate = new Map<Id, Payment_Log__c>();
        Map<Id, GiftCommitment> giftCommitmentsForUpdate = new Map<Id, GiftCommitment>();
        List<Payment_Reference__c> referencesForIntentCreation = new List<Payment_Reference__c>();
        GiftCommitment giftCommitment;

        for (Payment_Reference__c reference : paymentReferences) {
            if (reference.Payment_Log__r.isEmpty()) continue;
            Payment_Log__c paymentLog = reference.Payment_Log__r[0];
            StripeSetupIntentResponseWrapper setupIntent = StripeService.getSetupIntent(paymentLog.Setup_Intent__c);
            if (setupIntent == null || setupIntent?.error?.message != null) continue;
            paymentLog.Payment_Method_Id__c = setupIntent.payment_method;
            if(reference.Gift_Commitment__c != null) {
                giftCommitment = giftCommitmentsForUpdate.get(reference.Gift_Commitment__c) ?? new GiftCommitment(Id = reference.Gift_Commitment__c);
                giftCommitment.Stripe_Mandate_Id__c = setupIntent.mandate;
                giftCommitmentsForUpdate.put(reference.Gift_Commitment__c, giftCommitment);
            }
            
            if(paymentLog.Payment_Method__c == null){
                StripePaymentMethodResponseWrapper paymentMethodResponse = StripeService.getPaymentMethod(paymentLog.Payment_Method_Id__c);
                if (paymentMethodResponse == null || paymentMethodResponse?.error?.message != null) continue;
                paymentLog.Payment_Method__c = StripeUtil.convertStripePaymentMethod(paymentMethodResponse.type);
                giftCommitment.Payment_Method__c = giftCommitment.Payment_Method__c ?? StripeUtil.convertStripePaymentMethod(paymentMethodResponse.type);
                giftCommitmentsForUpdate.put(reference.Gift_Commitment__c, giftCommitment);
            }

            if(giftCommitment.Stripe_Mandate_Id__c != null){
                StripeMandateResponseWrapper mandateResponse = StripeService.getMandateDetails(giftCommitment.Stripe_Mandate_Id__c);
                if (mandateResponse == null || mandateResponse?.error?.message != null) continue;
                giftCommitment.Stripe_Mandate__c = mandateResponse?.payment_method_details?.sepa_debit?.reference;
                giftCommitmentsForUpdate.put(reference.Gift_Commitment__c, giftCommitment);
            }
            logsForUpdate.put(paymentLog.Id, paymentLog);
            referencesForIntentCreation.add(reference);
        }

        //createPaymentIntents(paymentReferences, logsForUpdate);
        update giftCommitmentsForUpdate.values();
        update logsForUpdate.values();

    }

    private static void updateRecurring(GiftCommitment giftCommitment, SObjectField field, Object value){
        giftCommitment.put(field, value);
    }

    public void execute(System.SchedulableContext SC) {
        Database.executeBatch(new StripeChargePaymentsBatch(), 10);
    }

    @TestVisible
    private class FetchPaymentMethodsQueueable implements Queueable, Database.AllowsCallouts {
        private Set<Id> paymentReferenceIds;

        public FetchPaymentMethodsQueueable(Set<Id> paymentReferenceIds) {
            this.paymentReferenceIds = paymentReferenceIds;
        }

        public void execute(QueueableContext param1) {
            fetchPaymentsMethodIds(paymentReferenceIds);
        }
    }
}