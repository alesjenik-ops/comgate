public with sharing class ComgateRecurringRequestWrapper {
    public Boolean test;
    public Decimal price;
    public String curr;
    public String label;
    public String refId;
    public String account;
    public String name;
    public String initRecurringId;

    public ComgateRecurringRequestWrapper(){
        this.test = !ComgateUtil.runningInASandbox;
    }

    public ComgateRecurringRequestWrapper(Opportunity opp) {
        this();
        this.price = opp.Amount * 100;
        this.curr = opp.CurrencyIsoCode;
        this.label = 'Comgate Test Donation';
        this.refId = opp.Id;
        if(opp.npe03__Recurring_Donation__r.npe03__Recurring_Donation_Campaign__r.Comgate_Bank_Account__c != null){
            this.account = opp.npe03__Recurring_Donation__r.npe03__Recurring_Donation_Campaign__r.Comgate_Bank_Account__c;
        }
        this.initRecurringId = opp.npe03__Recurring_Donation__r.Comgate_Initial_Transaction_Id__c;
    }

}