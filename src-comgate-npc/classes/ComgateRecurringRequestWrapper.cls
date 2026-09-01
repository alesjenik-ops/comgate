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
        this.test = ComgateUtil.isTestPayment;
    }

    public ComgateRecurringRequestWrapper(GiftTransaction giftTransaction) {
        this();
        this.price = giftTransaction.OriginalAmount * 100;
        this.curr = giftTransaction.CurrencyIsoCode ?? ComgateUtil.DEFAULT_CURRENCY;
        this.label = 'Dar';
        this.refId = giftTransaction.Id;
        if(giftTransaction.Campaign?.Comgate_Bank_Account__c != null){
            this.account = giftTransaction.Campaign.Comgate_Bank_Account__c;
        }
        this.initRecurringId = giftTransaction.GiftCommitment.Comgate_Initial_Transaction_Id__c;
    }

}
