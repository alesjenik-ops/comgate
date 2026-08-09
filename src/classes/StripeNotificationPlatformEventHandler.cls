public without sharing class StripeNotificationPlatformEventHandler {
    private static Map<Id, GiftCommitment> giftCommitmentsForUpdate = new Map<Id, GiftCommitment>();
    private static List<GiftTransaction> giftTransactionsForUpdate = new List<GiftTransaction>();
    private static List<Account> accountsForUpdate = new List<Account>();

    private static Map<Id, GiftTransaction> giftTransactionMap = new Map<Id, GiftTransaction>();
    private static Map<Id, GiftCommitment> giftCommitmentMap = new Map<Id, GiftCommitment>();
    private static Map<Id, Id> paymentReferenceMap = new Map<Id, Id>(); //PaymentReferenceId - OpportunityId/RecurringId
    
    private static Set<Id> paymentReferencesForMethodFetch = new Set<Id>();

    public static void afterInsert(List<Stripe_Notification__e> stripeNotifications){
        initializeMaps(stripeNotifications);

        for(Stripe_Notification__e notification : stripeNotifications){
            if(notification.Payment_Reference_Id__c == null || !(notification.Payment_Reference_Id__c instanceof Id)) continue;
            Id recordId = Payment_Reference__c.SObjectType == ((Id) notification.Payment_Reference_Id__c).getSobjectType()
                    ? paymentReferenceMap.get(notification.Payment_Reference_Id__c) : (Id) notification.Payment_Reference_Id__c;

            switch on notification.Type__c{
                when 'checkout.session.expired'{
                    handleClosedLost(notification, recordId, 'Session Expired');
                }
                when 'charge.expired'{
                    handleClosedLost(notification, recordId, 'Charge Expired');
                }
                when 'checkout.session.completed'{
                    handleCompletedSession(notification, recordId);
                }
                when 'charge.succeeded', 'charge.captured'{
                    handleChargeSucceeded(notification, recordId);
                }
                when 'charge.pending'{
                    handleChargePending(notification, recordId);
                }
                when 'charge.failed'{
                    handleChargeFailed(notification, recordId);
                }
                when 'charge.refunded'{
                    handleClosedLost(notification, recordId, 'Refunded');
                }
            }
        }
        update giftTransactionsForUpdate;
        update giftCommitmentsForUpdate.values();
        update accountsForUpdate;
        
        if(!paymentReferencesForMethodFetch.isEmpty()) StripeChargePaymentsBatch.fetchPaymentsMethodIds(paymentReferencesForMethodFetch);
    }
    
    private static void handleClosedLost(Stripe_Notification__e notification, Id recordId, String reason){
        if(GiftTransaction.SObjectType == recordId.getSobjectType()){
            GiftTransaction giftTransaction = giftTransactionMap.get(recordId);
            if(giftTransaction?.Status == StripeUtil.GIFT_TRANSACTION_PAID) return;
            giftTransactionsForUpdate.add(new GiftTransaction(
                    Id = recordId,
                    Status__c = 'ERROR',
                    Status_Reason__c = reason,
                    Status = StripeUtil.GIFT_TRANSACTION_FAILED
            ));
        } else if (GiftCommitment.SObjectType == recordId.getSobjectType()){
            giftCommitmentsForUpdate.put(recordId,
                    new GiftCommitment(Id = recordId, Status = 'Closed',
                            Description = reason));
        }
    }
    
    private static void handleCompletedSession(Stripe_Notification__e notification, Id recordId){
        if (GiftCommitment.SObjectType == recordId.getSobjectType()){
            giftCommitmentsForUpdate.put(recordId,
                    new GiftCommitment(Id = recordId, Stripe_Authorized__c = true,
                            Payment_Method__c = notification.Payment_Method__c));
            paymentReferencesForMethodFetch.add(notification.Payment_Reference_Id__c);
        }

        updateStripeCustomerId(notification.Stripe_Customer_Id__c, recordId);
    }
    
    private static void updateStripeCustomerId(String stripeCustomerId, Id recordId){
        if(stripeCustomerId == null) return;
        if (GiftCommitment.SObjectType == recordId.getSobjectType()){
            GiftCommitment giftCommitment = giftCommitmentMap.get(recordId);
            if(giftCommitment.DonorId == null || giftCommitment.Donor.Stripe_Customer_Id__c != null) return;
            accountsForUpdate.add(new Account(Id = giftCommitment.DonorId, Stripe_Customer_Id__c = stripeCustomerId));
        } else if (GiftTransaction.SObjectType == recordId.getSobjectType()){
            GiftTransaction giftTransaction = giftTransactionMap.get(recordId);
            if(giftTransaction.DonorId == null || giftTransaction.Donor.Stripe_Customer_Id__c != null) return;
            accountsForUpdate.add(new Account(Id = giftTransaction.DonorId, Stripe_Customer_Id__c = stripeCustomerId));
        }
    }

    private static void handleChargeSucceeded(Stripe_Notification__e notification, Id recordId){
        if(!(notification.Amount_Captured__c > 0)) return;
        
        if(GiftTransaction.SObjectType == recordId.getSobjectType() && giftTransactionMap.containsKey(recordId)){
            giftTransactionsForUpdate.add(preparePaidGiftTransaction(recordId, notification, giftTransactionMap.get(recordId).Attempt_Counter__c, true));
        
        } else if (GiftCommitment.SObjectType == recordId.getSobjectType()
                && giftCommitmentMap.containsKey(recordId)){
            //To handle CAPTURE of first recurring donation
            List<GiftTransaction> giftTransactions = giftCommitmentMap.get(recordId).GiftTransactions;
            if(giftTransactions.isEmpty()) return;
            giftTransactionsForUpdate.add(preparePaidGiftTransaction(giftTransactions[0].Id, notification, giftTransactions[0].Attempt_Counter__c, true));
        }
    }

    private static void handleChargePending(Stripe_Notification__e notification, Id recordId){
        if(GiftTransaction.SObjectType == recordId.getSobjectType() && giftTransactionMap.containsKey(recordId)){
            GiftTransaction giftTransaction = giftTransactionMap.get(recordId);
            if(giftTransaction.Status == StripeUtil.GIFT_TRANSACTION_PAID) return;
            StripeUtil.setDonationStatus(giftTransaction, 'PENDING',  '', null);
            giftTransactionsForUpdate.add(giftTransaction);
        }
    }

    private static void handleChargeFailed(Stripe_Notification__e notification, Id recordId){
        if(GiftTransaction.SObjectType == recordId.getSobjectType() && giftTransactionMap.containsKey(recordId)){
            GiftTransaction giftTransaction = preparePaidGiftTransaction(recordId, notification, giftTransactionMap.get(recordId).Attempt_Counter__c, false);
            if(giftTransaction.Stripe_Payment_Intent__c == null) giftTransaction.Stripe_Payment_Intent__c = notification.Payment_Intent__c;
            giftTransactionsForUpdate.add(giftTransaction);
        } else if (GiftCommitment.SObjectType == recordId.getSobjectType()
                && giftCommitmentMap.containsKey(recordId)){
            //To handle CAPTURE of first recurring donation
            List<GiftTransaction> giftTransactions = giftCommitmentMap.get(recordId).GiftTransactions;
            if(giftTransactions.isEmpty()) return;
            GiftTransaction giftTransaction = preparePaidGiftTransaction(giftTransactions[0].Id, notification, giftTransactions[0].Attempt_Counter__c, false);
            if(giftTransaction.Stripe_Payment_Intent__c == null) giftTransaction.Stripe_Payment_Intent__c = notification.Payment_Intent__c;
            giftTransactionsForUpdate.add(giftTransaction);
        }
    }
    
    private static GiftTransaction preparePaidGiftTransaction(Id giftTransactionId, Stripe_Notification__e notification, Decimal attemptCounter, Boolean success){
        GiftTransaction giftTransactionUpdate = new GiftTransaction(Id = giftTransactionId);
        if(success){
            giftTransactionUpdate.Status = StripeUtil.GIFT_TRANSACTION_PAID;
            giftTransactionUpdate.TransactionDate = Date.today();
            giftTransactionUpdate.Payment_Method__c = notification.Payment_Method__c;
            //oppUpdate.Stripe_Mandate_Id__c = oppUpdate.Stripe_Mandate_Id__c ?? notification.Mandate_Id__c;
            if(giftTransactionUpdate.Stripe_Payment_Intent__c == null) giftTransactionUpdate.Stripe_Payment_Intent__c = notification.Payment_Intent__c;
            StripeUtil.setDonationStatus(giftTransactionUpdate, 'CAPTURED',  '', null);
        } else {
            StripeUtil.setDonationStatus(giftTransactionUpdate, 'ERROR',  notification.Reason__c, attemptCounter);
        }
        return giftTransactionUpdate;
    }

    private static void initializeMaps(List<Stripe_Notification__e> stripeNotifications){
        Set<String> paymentReferences = new Set<String>();
        for(Stripe_Notification__e notification : stripeNotifications){
            paymentReferences.add(notification.Payment_Reference_Id__c);
        }

        for(Payment_Reference__c paymentReference : [SELECT Id, Gift_Transaction__c, Gift_Commitment__c FROM Payment_Reference__c WHERE Id IN: paymentReferences]){
            if(paymentReference.Gift_Transaction__c != null) paymentReferenceMap.put(paymentReference.Id, paymentReference.Gift_Transaction__c);
            if(paymentReference.Gift_Commitment__c != null) paymentReferenceMap.put(paymentReference.Id, paymentReference.Gift_Commitment__c);
        }

        giftTransactionMap = new Map<Id, GiftTransaction>([
                SELECT Id, Status, Attempt_Counter__c, GiftCommitmentId,
                        Status__c, OriginalAmount, Last_Attempt_Date__c, DonorId,
                        Donor.Stripe_Customer_Id__c, Stripe_Payment_Intent__c,
                        Payment_Method__c
                FROM GiftTransaction
                WHERE Id IN: paymentReferences OR Id IN: paymentReferenceMap.values()]);

        giftCommitmentMap = new Map<Id, GiftCommitment>([
                SELECT Id, Payment_Method__c, 
                    (SELECT Id, Status, Attempt_Counter__c, GiftCommitmentId,
                        Status__c, OriginalAmount, Last_Attempt_Date__c
                FROM GiftTransactions ORDER BY TransactionDueDate ASC LIMIT 1),
                        DonorId, Donor.Stripe_Customer_Id__c
                FROM GiftCommitment WHERE Id IN :paymentReferenceMap.values()
        ]);

    }
}