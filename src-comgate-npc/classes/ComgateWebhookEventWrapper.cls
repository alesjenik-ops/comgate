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

    public Payment_Log__c getPaymentLog(GiftTransaction giftTransaction, GiftCommitment giftCommitment, Payment_Reference__c paymentReference){
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

        if(ComgateUtil.isIdValid(this.refId)){
            if(((Id) this.refId).getSobjectType() == Schema.GiftTransaction.SObjectType){
                paymentLog.Gift_Transaction__c = this.refId;
            } else if(((Id) this.refId).getSobjectType() == Schema.GiftCommitment.SObjectType){
                paymentLog.Gift_Commitment__c = this.refId;
            } else if(((Id) this.refId).getSobjectType() == Schema.Payment_Reference__c.SObjectType){
                paymentLog.Payment_Reference__c = this.refId;
            }
        }

        if(paymentReference != null){
            if(paymentReference.Gift_Transaction__c != null) paymentLog.Gift_Transaction__c = paymentReference.Gift_Transaction__c;
            if(paymentReference.Gift_Commitment__c != null) paymentLog.Gift_Commitment__c = paymentReference.Gift_Commitment__c;
            paymentLog.Payment_Reference__c = paymentReference.Id;
        } else if(giftTransaction != null){
            paymentLog.Gift_Transaction__c = giftTransaction.Id;
        } else if (giftCommitment != null){
            paymentLog.Gift_Commitment__c = giftCommitment.Id;
        }
        return paymentLog;
    }
}
