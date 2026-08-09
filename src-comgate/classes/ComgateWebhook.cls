@RestResource(UrlMapping='/comgatewebhook')
global without sharing class ComgateWebhook {
    private static ComgatePaymentStatusResponseWrapper paymentStatusWrapper;
    private static ComgateWebhookEventWrapper eventWrapper;

    private static Map<Id, Opportunity> oppForUpdate = new Map<Id, Opportunity>();
    private static Map<Id, npe03__Recurring_Donation__c> recForUpdate = new Map<Id, npe03__Recurring_Donation__c>();

    private static Opportunity foundOpportunity;
    private static npe03__Recurring_Donation__c foundRecurring;
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
                    if(foundOpportunity != null) handlePaidOpportunity(foundOpportunity.Id);
                    if(foundRecurring != null) handlePaidRecurring(foundRecurring.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Opportunity__c != null){
                            handlePaidOpportunity(foundPaymentReference.Opportunity__c);
                        } else {
                            handlePaidRecurring(foundPaymentReference.Recurring_Donation__c);
                        }
                    }
                }
                when 'CANCELLED'{
                    if(foundOpportunity != null) handleCancelledOpportunity(foundOpportunity.Id);
                    if(foundRecurring != null) handleCancelledRecurring(foundRecurring.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Opportunity__c != null){
                            handleCancelledOpportunity(foundPaymentReference.Opportunity__c);
                        } else {
                            handleCancelledRecurring(foundPaymentReference.Recurring_Donation__c);
                        }
                    }
                }
                when 'AUTHORIZED'{
                    if(foundOpportunity != null) handleAuthorizedOpportunity(foundOpportunity.Id);
                    if(foundRecurring != null) handleAuthorizedRecurring(foundRecurring.Id);
                    if(foundPaymentReference != null){
                        if(foundPaymentReference.Opportunity__c != null){
                            handleAuthorizedOpportunity(foundPaymentReference.Opportunity__c);
                        } else {
                            handleAuthorizedRecurring(foundPaymentReference.Recurring_Donation__c);
                        }
                    }
                }
            }
            logs.add(eventWrapper.getPaymentLog(foundOpportunity, foundRecurring, foundPaymentReference));
        }
        insert logs;
        upsert oppForUpdate.values();
        upsert recForUpdate.values();

        RestResponse resp = RestContext.response;
        resp.statusCode = 200;
        resp.responseBody = Blob.valueOf('[accepted]');
    }

    private static void getRelatedObjects(String refId){
        if(refId == null) return;
        if(!(refId instanceof Id)) return;

        Id refIdLocal = (Id) refId;

        switch on refIdLocal.getSobjectType().getDescribe().name{
            when 'Opportunity'{
                foundOpportunity = [SELECT Id FROM Opportunity WHERE Id =: refIdLocal];
            }
            when 'npe03__Recurring_Donation__c'{
                foundRecurring = [SELECT Id FROM npe03__Recurring_Donation__c WHERE Id =: refIdLocal];
            }
            when 'Payment_Reference__c'{
                foundPaymentReference = [SELECT Id, Opportunity__c, Recurring_Donation__c,
                        Opportunity__r.Attempt_Counter__c, Opportunity__r.StageName
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


    private static void handlePaidOpportunity(Id opportunityId){
        Opportunity opp = oppForUpdate.get(opportunityId);
        if(opp == null) opp = new Opportunity(Id = opportunityId);

        opp.Attempt_Counter__c = 1;
        opp.Last_Attempt_Date__c = Date.today();
        opp.Comgate_Donation_Status_Reason__c = eventWrapper.paymentErrorReason;
        opp.Comgate_Donation_Status__c = eventWrapper.status;
        opp.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        opp.Comgate_Transaction_Id__c = eventWrapper.transId;
        opp.StageName = 'Posted';
        oppForUpdate.put(opp.Id, opp);
    }

    private static void handleCancelledOpportunity(Id opportunityId){
        Opportunity oppDetail = getOpportunityDetail(opportunityId);
        if(oppDetail.StageName == 'Posted') return;

        Opportunity opp = oppForUpdate.get(opportunityId);
        if(opp == null) opp = new Opportunity(Id = opportunityId);

        opp.Attempt_Counter__c = (oppDetail?.Attempt_Counter__c ?? 0) + 1;
        opp.Last_Attempt_Date__c = Date.today();
        opp.Comgate_Donation_Status_Reason__c = eventWrapper.paymentErrorReason;
        opp.Comgate_Donation_Status__c = eventWrapper.status;
        opp.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        opp.Comgate_Transaction_Id__c = eventWrapper.transId;
        if(oppDetail.npe03__Recurring_Donation__c == null) opp.StageName = 'Closed Lost';
        oppForUpdate.put(opp.Id, opp);
    }

    private static void handleAuthorizedOpportunity(Id opportunityId){
        Opportunity oppDetail = getOpportunityDetail(opportunityId);
        if(oppDetail.StageName == 'Posted') return;

        Opportunity opp = oppForUpdate.get(opportunityId);
        if(opp == null) opp = new Opportunity(Id = opportunityId);

        opp.Comgate_Donation_Status_Reason__c = eventWrapper.paymentErrorReason;
        opp.Comgate_Donation_Status__c = eventWrapper.status;
        opp.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        opp.Comgate_Transaction_Id__c = eventWrapper.transId;
        oppForUpdate.put(opp.Id, opp);
    }

    private static void handlePaidRecurring(Id recurringId){
        npe03__Recurring_Donation__c rec = recForUpdate.get(recurringId);
        if(rec == null) rec = new npe03__Recurring_Donation__c(Id = recurringId);

        npe03__Recurring_Donation__c recurringDetails = getRecurringDetails(recurringId);
        Opportunity opp = recurringDetails.npe03__Donations__r[0];
        handlePaidOpportunity(opp.Id);

        rec.Comgate_Recurring_Authorized__c = true;
        rec.Comgate_Initial_Transaction_Id__c = eventWrapper.transId;
        rec.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        recForUpdate.put(rec.Id, rec);
    }

    private static void handleCancelledRecurring(Id recurringId){
        npe03__Recurring_Donation__c rec = recForUpdate.get(recurringId);
        if(rec == null) rec = new npe03__Recurring_Donation__c(Id = recurringId);

        npe03__Recurring_Donation__c recurringDetails = getRecurringDetails(recurringId);
        Opportunity opp = recurringDetails.npe03__Donations__r[0];
        handleCancelledOpportunity(opp.Id);

        rec.npsp__Status__c = 'Closed';
        rec.npe03__Open_Ended_Status__c = 'Closed';
        recForUpdate.put(rec.Id, rec);
    }

    private static void handleAuthorizedRecurring(Id recurringId){
        npe03__Recurring_Donation__c rec = recForUpdate.get(recurringId);
        if(rec == null) rec = new npe03__Recurring_Donation__c(Id = recurringId);

        rec.Comgate_Recurring_Authorized__c = true;
        rec.Comgate_Initial_Transaction_Id__c = eventWrapper.transId;
        rec.Payment_Method__c = ComgateUtil.convertComgatePaymentMethod(eventWrapper.method);
        recForUpdate.put(rec.Id, rec);
    }

    private static npe03__Recurring_Donation__c getRecurringDetails(Id recurringId){
        return [SELECT Id, Comgate_Recurring__c, Comgate_Recurring_Authorized__c,
                Comgate_Initial_Transaction_Id__c, Payment_Method__c,
            (SELECT Id, StageName, Comgate_Transaction_Id__c, Payment_Method__c,
                    Attempt_Counter__c
                FROM npe03__Donations__r ORDER BY CloseDate ASC)
        FROM npe03__Recurring_Donation__c WHERE Id = :recurringId];
    }

    private static Opportunity getOpportunityDetail(Id oppId){
        return [SELECT Id, StageName, Attempt_Counter__c, npe03__Recurring_Donation__c FROM Opportunity WHERE Id =: oppId];
    }
}