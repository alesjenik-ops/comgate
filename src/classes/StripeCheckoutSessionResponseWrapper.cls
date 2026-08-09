public with sharing class StripeCheckoutSessionResponseWrapper {
    public String id;
    public String object_x;
    @AuraEnabled public String status;
    public Decimal amount;
    public Decimal amount_capturable;
    public Decimal amount_received;
    public String capture_method;
    @AuraEnabled public String client_secret;
    @AuraEnabled public String return_url;
    public Boolean livemode;

    public StripeCheckoutSessionResponseWrapper deserializeJSON(String inputJson){
        return (StripeCheckoutSessionResponseWrapper) JSON.deserialize(inputJson.replaceAll('currency','currency_x')
                .replaceAll('object','object_x'), StripeCheckoutSessionResponseWrapper.class);
    }
}