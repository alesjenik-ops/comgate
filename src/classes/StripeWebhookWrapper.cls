public with sharing class StripeWebhookWrapper {
    public String id;
    public String object_x;
    public String api_version;
    public String type; //e.g. checkout.session.completed
    public Boolean livemode;
    public Integer pending_webhooks;
    public Long created; //UTC timestamp
    public WrapperData data;
    
    public class WrapperData{
        public WrapperObject object_x;
    }
    
    public class WrapperObject{
        public String id;
        public String object_x;
        public String client_reference_id;
        public ConsentWrapper consent;
        public Long created; //UTC timestamp
        public Long expires_at; //UTC timestamp
        public String currency_x;
        public String customer; //customer ID
        public Decimal amount_total;
        public Decimal amount_captured;
        public Decimal amount;
        public String setup_intent; //e.g. seti_1OGmftLqN4DuZlYxkWz3esMf
        public String status; //e.g. complete
        public String reason; 
        public String ui_mode;
        public String mode;
        public String payment_status;
        public String payment_intent;
        public MetadataWrapper metadata;
        public OutcomeWrapper outcome;
        public PaymentMethodDetails payment_method_details;
        public List<String> payment_method_types;
    }
    
    public class ConsentWrapper{
        public String promotions;
        public String terms_of_service;
    }
    
    public class OutcomeWrapper{
        public String network_status;
        public String reason;
        public String risk_level;
        public Decimal risk_score;
        public String seller_message;
        public String type;
    }
    
    public class MetadataWrapper{
        public String payment_reference;
        public String opportunity_reference;
    }
    
    public class PaymentMethodDetails{
        public String type;
        public PaymentMethodDetailWrapper sepa_debit;
    }

    public class PaymentMethodDetailWrapper{
        public String mandate;
    }

    public StripeWebhookWrapper deserializeJSON(String inputJson){
        return (StripeWebhookWrapper) JSON.deserialize(inputJson
                .replaceAll('currency','currency_x')
                .replaceAll('object','object_x'), StripeWebhookWrapper.class);
    }

    public Payment_Log__c getPaymentLog(){
        Payment_Log__c log =  new Payment_Log__c(
                Amount__c = getAmount(),
                Currency__c = this.data.object_x.currency_x,
                Event_Code__c = this.type,
                Event_Date__c = StripeUtil.getDateFromUTCStamp(this.data.object_x.created),
                Expiry_Date__c = StripeUtil.getDateFromUTCStamp(this.data.object_x.expires_at),
                Payment_Method__c = getPaymentMethod(),
                Setup_Intent__c = this.data.object_x?.setup_intent,
                Status__c = this.data.object_x.status,
                Payment_Mode__c = this.data.object_x.mode,
                Gift_Transaction__c = getOpportunityId()
                
        );
        
        String paymentReference = getPaymentReference();
        if(StripeUtil.isIdValid(paymentReference)){
            if(GiftTransaction.SObjectType == ((Id) paymentReference).getSobjectType()){
                log.Gift_Transaction__c = ((Id) paymentReference);
            } else if (GiftCommitment.SObjectType == ((Id) paymentReference).getSobjectType()){
                log.Gift_Commitment__c = ((Id) paymentReference);
            }else if (Payment_Reference__c.SObjectType == ((Id) paymentReference).getSobjectType()){
                log.Payment_Reference__c = ((Id) paymentReference);
            }
        }
        
        return log;
    }
    
    public String getOpportunityId(){
        String donationReference = getDonationReference();
        if(StripeUtil.isIdValid(donationReference)
                && GiftTransaction.SObjectType == ((Id) donationReference).getSobjectType()) return donationReference;
        return null;
    }
    
    public String getPaymentReference(){
        if(this.data.object_x?.client_reference_id != null) return this.data.object_x.client_reference_id;
        if(this.data.object_x?.metadata?.payment_reference != null) return this.data.object_x.metadata.payment_reference;
        return null;
    }
    
    public String getDonationReference(){
        if(this.data.object_x?.metadata?.opportunity_reference != null) return this.data.object_x.metadata.opportunity_reference;
        return getPaymentReference();
    }
    
    public String getPaymentMethod(){
        return StripeUtil.convertStripePaymentMethod(this.data.object_x?.payment_method_details?.type);
    }
    
    private Decimal getAmount(){
        Decimal inputValue;
        if (this.data.object_x.amount_captured != null){
            inputValue = this.data.object_x.amount_captured;
        } else if (this.data.object_x.amount_total != null) {
            inputValue = this.data.object_x.amount_total;
        } else {
            inputValue = this.data.object_x.amount;
        }
        if(inputValue == null || this.data.object_x.currency_x == null) return null;
        return inputValue / StripeUtil.currencyMultiplier(this.data.object_x.currency_x);
    }
}