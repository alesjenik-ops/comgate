//https://stripe.com/docs/api/setup_intents/object
public with sharing class StripeSetupIntentResponseWrapper extends StripeErrorResponseWrapper{
    public String id;
    public String payment_method;
    public String mandate;
    public String[] payment_method_types;
}