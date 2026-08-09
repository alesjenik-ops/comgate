//https://stripe.com/docs/api/payment_intents/create

public with sharing class StripePaymentIntentRequestWrapper {
    public Decimal amount; //e.g., 100 cents to charge $1.00 or 100 to charge ¥100, a zero-decimal currency
    public String currency_x;
    public String receipt_email;
    public String customer;
    public String payment_method_id;
    public String payment_method_type;
    public String paymentReference;
    public String opportunityReference;
    public String radarSessionId;
    public ContactWrapper name;

    public class ContactWrapper{
        public String name;
    }

    public StripePaymentIntentRequestWrapper(Decimal amount, String currencyIsoCode, String paymentMethodIdentifier, 
            String paymentMethodType, String stripeCustomerId, Id opportunityId, String paymentReference, String radarSessionId){
        this.amount = StripeUtil.currencyMultiplier(currencyIsoCode) * amount;
        this.currency_x = currencyIsoCode;
        this.payment_method_id = paymentMethodIdentifier;
        this.payment_method_type = paymentMethodType;
        this.customer = stripeCustomerId;
        this.paymentReference = paymentReference;
        this.opportunityReference = opportunityId;
        this.radarSessionId = radarSessionId;
    }

    public String serializeWrapper(){
        String payload = 'currency=' + this.currency_x
                + '&amount=' + this.amount.intValue()
                + '&payment_method=' + this.payment_method_id
                + '&customer=' + this.customer
                + '&metadata[payment_reference]=' + this.paymentReference
                + '&metadata[opportunity_reference]=' + this.opportunityReference
                + '&confirm=true' +
                + '&off_session=true';
        if(radarSessionId != null) payload += '&radar_options[session]=' + radarSessionId;

        if (payment_method_type == 'SEPA Direct Debit'){
            payload += '&capture_method=automatic' +
                    + '&payment_method_types[0]=sepa_debit';
        } else {
            payload += '&capture_method=automatic' +
                    + '&automatic_payment_methods[enabled]=true'
                    + '&automatic_payment_methods[allow_redirects]=never';
        }
        return payload;
    }

}