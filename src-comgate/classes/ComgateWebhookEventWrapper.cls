public with sharing class ComgateWebhookEventWrapper {
    public String transId;
    public String merchant;
    public String test;
    public Decimal price;
    public String curr;
    public String label;
    public String refId;
    public String payerId;
    public String payerName;
    public String payerAcc;
    public String method;
    public String account;
    public String email;
    public String phone;
    public String name;
    public String secret;
    public String status; //Current transaction status (PAID, CANCELLED, AUTHORIZED)
    public String fee;
    public String vs;
    public String fullName;
    public String billingAddrCity;
    public String billingAddrStreet;
    public String billingAddrPostalCode;
    public String billingAddrCountry;
    public String delivery;
    public String homeDeliveryCity;
    public String homeDeliveryStreet;
    public String homeDeliveryPostalCode;
    public String homeDeliveryCountry;
    public String category;
    public Decimal appliedFee;
    public String appliedFeeType;
    public String paymentErrorReason;

    public Payment_Log__c getPaymentLog(Opportunity opp, npe03__Recurring_Donation__c rec, Payment_Reference__c paymentReference){
        Payment_Log__c paymentLog = new Payment_Log__c(
                Merchant_Code__c = this.merchant,
                Is_Test__c = this.test == 'true',
                Amount__c = this.price / 100,
                Currency__c = this.curr,
                Payment_Method__c = this.method,
                Transaction_Id__c = this.transId,
                Status__c = this.status,
                Variable__c = this.vs,
                Status_Reason__c = this.paymentErrorReason,
                CurrencyIsoCode = curr
        );

        if(((Id) this.refId).getSobjectType() == Opportunity.SObjectType){
            paymentLog.Opportunity__c = this.refId;
        } else if(((Id) this.refId).getSobjectType() == npe03__Recurring_Donation__c.SObjectType){
            paymentLog.Recurring_Donation__c = this.refId;
        } else if(((Id) this.refId).getSobjectType() == Payment_Reference__c.SObjectType){
            paymentLog.Payment_Reference__c = this.refId;
        }

        if(paymentReference != null){
            if(paymentReference.Opportunity__c != null) paymentLog.Opportunity__c = paymentReference.Opportunity__c;
            if(paymentReference.Recurring_Donation__c != null) paymentLog.Recurring_Donation__c = paymentReference.Recurring_Donation__c;
            paymentLog.Payment_Reference__c = paymentReference.Id;
        } else if(opp != null){
            paymentLog.Opportunity__c = opp.Id;
        } else if (rec != null){
            paymentLog.Recurring_Donation__c = rec.Id;
        }
        return paymentLog;
    }
}