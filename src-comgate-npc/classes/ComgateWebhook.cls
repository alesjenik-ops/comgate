@RestResource(UrlMapping='/comgatewebhook')
global without sharing class ComgateWebhook {
    private static ComgatePaymentStatusResponseWrapper paymentStatusWrapper;
    private static ComgateWebhookEventWrapper eventWrapper;

    private static Map<Id, GiftTransaction> giftTransactionForUpdate = new Map<Id, GiftTransaction>();
    private static Map<Id, GiftCommitment> giftCommitmentForUpdate = new Map<Id, GiftCommitment>();

    private static GiftTransaction foundGiftTransaction;
    private static GiftCommitment foundGiftCommitment;
    private static Payment_Reference__c foundPaymentReference;

    @HttpPost
    global static void doPost() {
        List<Payment_Log__c> logs = new List<Payment_Log__c>();
        RestRequest req = RestContext.request;
        System.debug(req.requestBody);
        System.debug(req.requestBody.toString());

        eventWrapper = (ComgateWebhookEventWrapper) JSON.deserialize(req.requestBody.toString(), ComgateWebhookEventWrapper.class);
        paymentStatusWrapper = getPaymentStatus(eventWrapper);
        Boolean isStatusValid = verifyStatus(eventWrapper, paymentStatusWrapper);

        if(isStatusValid){
            getRelatedObjects(eventWrapper.refId);

            switch on eventWrapper.status{
                when 'PAID'{
                    if(foundGiftTransaction != null) handlePaidGiftTransaction(foundGiftTransaction.Id);
                    if(foundGiftCommitment != null) handlePaidRecurring(foundGiftCommitment.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Gift_Transaction__c != null){
                            handlePaidGiftTransaction(foundPaymentReference.Gift_Transaction__c);
                        } else {
                            handlePaidRecurring(foundPaymentReference.Gift_Commitment__c);
                        }
                    }
                }
                when 'CANCELLED'{
                    if(foundGiftTransaction != null) handleCancelledGiftTransaction(foundGiftTransaction.Id);
                    if(foundGiftCommitment != null) handleCancelledRecurring(foundGiftCommitment.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Gift_Transaction__c != null){
                            handleCancelledGiftTransaction(foundPaymentReference.Gift_Transaction__c);
                        } else {
                            handleCancelledRecurring(foundPaymentReference.Gift_Commitment__c);
                        }
                    }
                }
                when 'AUTHORIZED'{
                    if(foundGiftTransaction != null) handleAuthorizedGiftTransaction(foundGiftTransaction.Id);
                    if(foundGiftCommitment != null) handleAuthorizedRecurring(foundGiftCommitment.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Gift_Transaction__c != null){
                            handleAuthorizedGiftTransaction(foundPaymentReference.Gift_Transaction__c);
                        } else {
                            handleAuthorizedRecurring(foundPaymentReference.Gift_Commitment__c);
                        }
                    }
                }
            }
            logs.add(eventWrapper.getPaymentLog(foundGiftTransaction, foundGiftCommitment, foundPaymentReference));
        }
        insert logs;
        upsert giftTransactionForUpdate.values();
        upsert giftCommitmentForUpdate.values();

        RestResponse resp = RestContext.response;
        resp.statusCode = 200;
        resp.responseBody = Blob.valueOf('[accepted]');
    }

    private static void getRelatedObjects(String refId){
        if(refId == null) return;
        if(!(refId instanceof Id)) return;

        Id refIdLocal = (Id) refId;

        switch on refIdLocal.getSobjectType().getDescribe().name{
            when 'GiftTransaction'{
                foundGiftTransaction = [SELECT Id FROM GiftTransaction WHERE Id =: refIdLocal];
            }
            when 'GiftCommitment'{
                foundGiftCommitment = [SELECT Id FROM GiftCommitment WHERE Id =: refIdLocal];
            }
            when 'Payment_Reference__c'{
                foundPaymentReference = [SELECT Id, Gift_Transaction__c, Gift_Commitment__c,
                        Gift_Transaction__r.Attempt_Counter__c, Gift_Transaction__r.Status
                FROM Payment_Reference__c WHERE Id = :refIdLocal];
            }
        }
    }

    private static ComgatePaymentStatusResponseWrapper getPaymentStatus(ComgateWebhookEventWrapper eventWrapper){
        return ComgateService.getPaymentStatus(eventWrapper.transId);
    }

    private static Boolean verifyStatus(ComgateWebhookEventWrapper eventWrapper, ComgatePaymentStatusResponseWrapper paymentStatusWrapper){
        return paymentStatusWrapper?.status == eventWrapper.status;
    }


    private static void handlePaidGiftTransaction(Id giftTransactionId){
        GiftTransaction giftTransaction = giftTransactionForUpdate.get(giftTransactionId);
        if(giftTransaction == null) giftTransaction = new GiftTransaction(Id = giftTransactionId);

        giftTransaction.Attempt_Counter__c = 1;
        giftTransaction.Last_Attempt_Date__c = Datetime.now();
        giftTransaction.Status_Reason__c = eventWrapper.paymentErrorReason;
        giftTransaction.Status__c = eventWrapper.status;
        giftTransaction.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        giftTransaction.Comgate_Transaction_Id__c = eventWrapper.transId;
        giftTransaction.Status = ComgateUtil.GIFT_TRANSACTION_PAID;
        giftTransaction.TransactionDate = Date.today();
        giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
    }

    private static void handleCancelledGiftTransaction(Id giftTransactionId){
        GiftTransaction giftTransactionDetail = getGiftTransactionDetail(giftTransactionId);
        if(giftTransactionDetail.Status == ComgateUtil.GIFT_TRANSACTION_PAID) return;

        GiftTransaction giftTransaction = giftTransactionForUpdate.get(giftTransactionId);
        if(giftTransaction == null) giftTransaction = new GiftTransaction(Id = giftTransactionId);

        giftTransaction.Attempt_Counter__c = (giftTransactionDetail?.Attempt_Counter__c ?? 0) + 1;
        giftTransaction.Last_Attempt_Date__c = Datetime.now();
        giftTransaction.Status_Reason__c = eventWrapper.paymentErrorReason;
        giftTransaction.Status__c = eventWrapper.status;
        giftTransaction.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        giftTransaction.Comgate_Transaction_Id__c = eventWrapper.transId;
        if(giftTransactionDetail.GiftCommitmentId == null) giftTransaction.Status = ComgateUtil.GIFT_TRANSACTION_FAILED;
        giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
    }

    private static void handleAuthorizedGiftTransaction(Id giftTransactionId){
        GiftTransaction giftTransactionDetail = getGiftTransactionDetail(giftTransactionId);
        if(giftTransactionDetail.Status == ComgateUtil.GIFT_TRANSACTION_PAID) return;

        GiftTransaction giftTransaction = giftTransactionForUpdate.get(giftTransactionId);
        if(giftTransaction == null) giftTransaction = new GiftTransaction(Id = giftTransactionId);

        giftTransaction.Status_Reason__c = eventWrapper.paymentErrorReason;
        giftTransaction.Status__c = eventWrapper.status;
        giftTransaction.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        giftTransaction.Comgate_Transaction_Id__c = eventWrapper.transId;
        giftTransactionForUpdate.put(giftTransaction.Id, giftTransaction);
    }

    private static void handlePaidRecurring(Id giftCommitmentId){
        if(giftCommitmentId == null) return;
        GiftCommitment giftCommitment = giftCommitmentForUpdate.get(giftCommitmentId);
        if(giftCommitment == null) giftCommitment = new GiftCommitment(Id = giftCommitmentId);

        GiftTransaction earliestUnpaid = getEarliestUnpaidGiftTransaction(giftCommitmentId);
        if(earliestUnpaid != null) handlePaidGiftTransaction(earliestUnpaid.Id);

        giftCommitment.Comgate_Authorized__c = true;
        giftCommitment.Comgate_Initial_Transaction_Id__c = eventWrapper.transId;
        giftCommitment.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        giftCommitmentForUpdate.put(giftCommitment.Id, giftCommitment);
    }

    private static void handleCancelledRecurring(Id giftCommitmentId){
        if(giftCommitmentId == null) return;
        GiftCommitment giftCommitment = giftCommitmentForUpdate.get(giftCommitmentId);
        if(giftCommitment == null) giftCommitment = new GiftCommitment(Id = giftCommitmentId);

        GiftTransaction earliestUnpaid = getEarliestUnpaidGiftTransaction(giftCommitmentId);
        if(earliestUnpaid != null) handleCancelledGiftTransaction(earliestUnpaid.Id);

        giftCommitment.Status = 'Closed';
        giftCommitmentForUpdate.put(giftCommitment.Id, giftCommitment);
    }

    private static void handleAuthorizedRecurring(Id giftCommitmentId){
        if(giftCommitmentId == null) return;
        GiftCommitment giftCommitment = giftCommitmentForUpdate.get(giftCommitmentId);
        if(giftCommitment == null) giftCommitment = new GiftCommitment(Id = giftCommitmentId);

        giftCommitment.Comgate_Authorized__c = true;
        giftCommitment.Comgate_Initial_Transaction_Id__c = eventWrapper.transId;
        giftCommitment.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        giftCommitmentForUpdate.put(giftCommitment.Id, giftCommitment);
    }

    private static GiftTransaction getEarliestUnpaidGiftTransaction(Id giftCommitmentId){
        List<GiftTransaction> giftTransactions = [SELECT Id, Status, Attempt_Counter__c FROM GiftTransaction
                WHERE GiftCommitmentId = :giftCommitmentId AND Status = :ComgateUtil.GIFT_TRANSACTION_UNPAID
                ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransactions.isEmpty()) return null;
        return giftTransactions[0];
    }

    private static GiftTransaction getGiftTransactionDetail(Id giftTransactionId){
        return [SELECT Id, Status, Attempt_Counter__c, GiftCommitmentId FROM GiftTransaction WHERE Id =: giftTransactionId];
    }
}
