public with sharing class ComgateChargePaymentsBatch implements Database.Batchable<SObject>, System.Schedulable, Database.AllowsCallouts{
    private final Id oppId;
    private Map<Id, Opportunity> opportunityForUpdate = new Map<Id, Opportunity>();

    public ComgateChargePaymentsBatch() {
    }

    public ComgateChargePaymentsBatch(Id oppId) {
        this.oppId = oppId;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        Decimal attemptCounterLimit = ComgateUtil.comgateSettings.Attempt_Limit__c;
        Date lastAttemptDate = Date.today().addDays(-ComgateUtil.comgateSettings.Attempt_Delay__c.intValue()) + 1;
        Boolean nextChargingDateToday = isChargingDateToday();

        String query = 'SELECT Id, npe03__Recurring_Donation__c, Comgate_Donation_Status__c, Amount, Last_Attempt_Date__c, ' +
                ' CloseDate, ContactId, Attempt_Counter__c, Payment_Method__c, Comgate_Transaction_Id__c, ' +
                ' npe03__Recurring_Donation__r.Comgate_Initial_Transaction_Id__c, CurrencyIsoCode, ' +
                ' npe03__Recurring_Donation__r.npe03__Recurring_Donation_Campaign__r.Comgate_Bank_Account__c, ' +
                ' Comgate_Donation_Status_Reason__c ' +
                ' FROM Opportunity ';
        if (oppId == null) {
            query += ' WHERE StageName = \'Pledged\' ' +
                    '   AND npe03__Recurring_Donation__r.Comgate_Authorized__c = TRUE ' +
                    ' AND ((CloseDate < TODAY ' +
                    '    AND Comgate_Donation_Status__c != null ' +
                    '    AND (Attempt_Counter__c < :attemptCounterLimit OR Attempt_Counter__c = null) ' +
                    '    AND (Last_Attempt_Date__c = NULL OR Last_Attempt_Date__c < :lastAttemptDate)) ' +
                    getRecurringQueryPart(nextChargingDateToday) +
                    ')';
        }
        if (oppId != null) query += ' WHERE Id = :oppId';
        return Database.getQueryLocator(query);
    }

    private static String getRecurringQueryPart(Boolean nextChargingDateToday) {
        if (nextChargingDateToday) {
            return 'OR (npe03__Recurring_Donation__r.Comgate_Recurring__c = TRUE ' +
                    '   AND CloseDate <= TODAY  ' +
                    '   AND Last_Attempt_Date__c = NULL ' +
                    '   AND Comgate_Donation_Status__c = NULL)';
        }
        return '';
    }


    private static Boolean isChargingDateToday() {
        return Date.today().day() == ComgateUtil.comgateSettings.Day_Of_Charging__c
                || ComgateUtil.comgateSettings.Day_Of_Charging__c == 0
                || ComgateUtil.comgateSettings.Day_Of_Charging__c == null;
    }

    public void execute(Database.BatchableContext BC, List<Opportunity> scope) {
        processOpportunities(scope);
    }

    public void processOpportunities(List<Opportunity> scope) {
        List<Opportunity> oppForUpdate = new List<Opportunity>();
        for(Opportunity opp : scope){
            ComgateRecurringRequestWrapper requestWrapper = new ComgateRecurringRequestWrapper(opp);
            ComgatePaymentResponseWrapper responseWrapper = ComgateService.getRecurringPayment(requestWrapper);
            if(responseWrapper?.code == null){
                opp.Last_Attempt_Date__c = Date.today();
                opp.Attempt_Counter__c = (opp.Attempt_Counter__c ?? 0) + 1;
                opp.Comgate_Donation_Status_Reason__c = responseWrapper.code + ' ' + responseWrapper.message;
                if(opp.Attempt_Counter__c >= ComgateUtil.comgateSettings.Attempt_Limit__c) {
                    opp.StageName = 'Closed Lost';
                }
                oppForUpdate.add(opp);
            }
        }
        update oppForUpdate;
    }

    public void finish(Database.BatchableContext BC) {

    }

    public void execute(System.SchedulableContext SC) {
        Database.executeBatch(new ComgateChargePaymentsBatch(), 10);
    }
}