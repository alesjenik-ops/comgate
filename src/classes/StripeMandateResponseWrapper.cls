public with sharing class StripeMandateResponseWrapper extends StripeErrorResponseWrapper{
    public PaymentMethodDetailsWrapper payment_method_details;

    public class PaymentMethodDetailsWrapper{
        public PaymentMethodDetailWrapper sepa_debit;
    }

    public class PaymentMethodDetailWrapper{
        public String reference;
    }
}