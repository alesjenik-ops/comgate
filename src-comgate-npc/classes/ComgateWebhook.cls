@RestResource(UrlMapping='/comgatewebhook')
global without sharing class ComgateWebhook {
    private static ComgatePaymentStatusResponseWrapper paymentStatusWrapper;
    private static ComgateWebhookEventWrapper eventWrapper;

    private static Map<Id, GiftTransaction> giftTransactionForUpdate = new Map<Id, GiftTransaction>();
    private static Map<Id, GiftCommitment> giftCommitmentForUpdate = new Map<Id, GiftCommitment>();

    private static GiftTransaction foundGiftTransaction;
    private static GiftCommitment foundGiftCommitment;
    private static Payment_Reference__c foundPaymentReference;

    private static final String STATUS_PROCESSED = 'Processed';
    private static final String STATUS_FAILED = 'Failed';
    private static final String STATUS_UNVERIFIED = 'Unverified';

    @HttpPost
    global static void doPost() {
        reset();
        RestResponse resp = RestContext.response;
        RestRequest req = RestContext.request;
        String rawBody = req != null && req.requestBody != null ? req.requestBody.toString() : null;

        try {
            eventWrapper = (ComgateWebhookEventWrapper) JSON.deserialize(rawBody, ComgateWebhookEventWrapper.class);
        } catch (Exception e) {
            // Telo nejde precist, nema se k cemu zalogovat platbu - jedina cesta, kdy nevracime 200
            logError('Telo requestu nejde precist jako Comgate report: ' + e.getMessage());
            respond(resp, 400, '[rejected]');
            return;
        }
        // Telo requestu se zamerne neloguje cele - jsou v nem osobni udaje darce a pole secret
        System.debug('Comgate report ' + eventWrapper.transId + ', status ' + eventWrapper.status);

        String processingStatus = STATUS_PROCESSED;
        String processingError = null;
        try {
            paymentStatusWrapper = getPaymentStatus(eventWrapper);
            if (verifyStatus(eventWrapper, paymentStatusWrapper)) {
                getRelatedObjects(eventWrapper.refId);
                applyStatus();
                processingError = saveRecords();
                if (processingError != null) processingStatus = STATUS_FAILED;
            } else {
                // Comgate status API nepotvrdilo stav z payloadu - zamerne nic nemenime, ale report zaznamename
                processingStatus = STATUS_UNVERIFIED;
                processingError = 'Status z payloadu (' + eventWrapper.status + ') neodpovida stavu z Comgate status API ('
                        + (paymentStatusWrapper == null ? 'bez odpovedi' : paymentStatusWrapper.status) + ').';
            }
        } catch (Exception e) {
            processingStatus = STATUS_FAILED;
            processingError = e.getTypeName() + ' na radku ' + e.getLineNumber() + ': ' + e.getMessage();
        }

        Boolean recorded = savePaymentLog(processingStatus, processingError);
        if (processingStatus != STATUS_PROCESSED) {
            logError('Report ' + eventWrapper.transId + ' skoncil jako ' + processingStatus + '. ' + processingError);
        }

        // 200 jen kdyz report skutecne zustal v Payment_Log__c. HTTP 500 Comgate po tretim pokusu
        // vypne hlaseni na cely den, a to pro VSECHNY darce, ne jen pro tuhle platbu - proto se vraci
        // i kdyz se dary nezapsaly. Zaznam se stavem jinym nez Processed je signal k prehrani reportu.
        // Kdyz se nepodarilo zapsat ani log, neni co dohledat a 500 je na miste: at to Comgate zkusi znovu.
        respond(resp, recorded ? 200 : 500, recorded ? '[accepted]' : '[not recorded]');
    }

    // Staticke stavy prezivaji v ramci jedne transakce - pri opakovanem volani (testy) je nutne je vycistit
    private static void reset() {
        giftTransactionForUpdate.clear();
        giftCommitmentForUpdate.clear();
        eventWrapper = null;
        paymentStatusWrapper = null;
        foundGiftTransaction = null;
        foundGiftCommitment = null;
        foundPaymentReference = null;
    }

    private static void applyStatus() {
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
    }

    // allOrNone = false: kdyz na jednom zaznamu selze automatizace (napr. record-triggered flow),
    // nesmi to zahodit cely zapis vcetne Payment_Log__c. Chyby se vraci k zalogovani.
    private static String saveRecords() {
        List<String> problems = new List<String>();
        if (!giftTransactionForUpdate.isEmpty()) {
            problems.addAll(upsertProblems(Database.upsert(giftTransactionForUpdate.values(), false), 'GiftTransaction'));
        }
        if (!giftCommitmentForUpdate.isEmpty()) {
            problems.addAll(upsertProblems(Database.upsert(giftCommitmentForUpdate.values(), false), 'GiftCommitment'));
        }
        return problems.isEmpty() ? null : String.join(problems, '\n');
    }

    private static List<String> upsertProblems(List<Database.UpsertResult> results, String objectName) {
        List<String> problems = new List<String>();
        for (Database.UpsertResult result : results) {
            if (result.isSuccess()) continue;
            for (Database.Error error : result.getErrors()) {
                problems.add(objectName + ' ' + result.getId() + ': ' + error.getStatusCode() + ' - ' + error.getMessage());
            }
        }
        return problems;
    }

    // Log vznika VZDY, i kdyz se dary nepodarilo zapsat nebo se stav neoveril - jinak by po
    // navratu 200 nezustala po platbe v orgu zadna stopa a nemel by ji kdo dohledat.
    private static Boolean savePaymentLog(String processingStatus, String processingError) {
        try {
            insert stampLog(eventWrapper.getPaymentLog(foundGiftTransaction, foundGiftCommitment, foundPaymentReference),
                    processingStatus, processingError);
            return true;
        } catch (Exception e) {
            // Nejcastejsi pricina je lookup na zaznam, ktery v orgu neni (smazany nebo cizi refId)
            logError('Payment_Log__c se nepodarilo ulozit s vazbami: ' + e.getMessage());
        }
        try {
            // Druhy pokus bez vazeb - po platbe ma zustat aspon transId, castka a stav
            Payment_Log__c bare = eventWrapper.getPaymentLog(null, null, null);
            bare.Gift_Transaction__c = null;
            bare.Gift_Commitment__c = null;
            bare.Payment_Reference__c = null;
            insert stampLog(bare, processingStatus, processingError);
            return true;
        } catch (Exception e) {
            logError('Payment_Log__c se nepodarilo ulozit ani bez vazeb: ' + e.getMessage());
            return false;
        }
    }

    private static Payment_Log__c stampLog(Payment_Log__c paymentLog, String processingStatus, String processingError) {
        paymentLog.Processing_Status__c = processingStatus;
        paymentLog.Processing_Error__c = processingError == null ? null : processingError.abbreviate(32000);
        return paymentLog;
    }

    private static void logError(String message) {
        try {
            insert new CRMforNonProfit__Error_Log__c(
                    CRMforNonProfit__Class_Name__c = 'ComgateWebhook',
                    CRMforNonProfit__Error_Message__c = message == null ? null : message.abbreviate(32000),
                    CRMforNonProfit__Record_Id__c = eventWrapper == null ? null : eventWrapper.transId,
                    CRMforNonProfit__Keyword__c = 'Comgate webhook'
            );
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error log se nepodarilo zapsat: ' + e.getMessage());
        }
    }

    private static void respond(RestResponse resp, Integer statusCode, String body) {
        if (resp == null) return;
        resp.statusCode = statusCode;
        resp.responseBody = Blob.valueOf(body);
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
