public with sharing class StripeService {
    private static final List<Integer> ERROR_CODES = new List<Integer>{
      400, 401, 402, 403, 404, 409, 429, 500, 502, 503, 504      
    };
    public static StripeCheckoutSessionResponseWrapper createCheckoutSession(String paymentReferenceId, 
            DonationPagePaymentWrapper paymentWrapper, Account donor){
        StripeCheckoutSessionRequestWrapper paymentIntentWrapper = new StripeCheckoutSessionRequestWrapper(paymentReferenceId, paymentWrapper, donor);
        HttpResponse res = StripeCallouts.doCallout(StripeCallouts.URL_CHECKOUT_SESSION, 'POST', paymentIntentWrapper.serializeWrapper());
        if(res.getStatusCode() == 200){
            StripeCheckoutSessionResponseWrapper paymentIntentResponse = new StripeCheckoutSessionResponseWrapper().deserializeJSON(res.getBody());
            System.debug(res.getBody());
            System.debug(paymentIntentResponse);
            return paymentIntentResponse;
        } else {
            return null;
        }
    }
    
    public static StripeSetupIntentResponseWrapper getSetupIntent(String setupIntentKey){
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_SETUP_INTENTS + '/' + setupIntentKey, 
                'GET', 
                null);
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripeSetupIntentResponseWrapper paymentIntentResponse = (StripeSetupIntentResponseWrapper) JSON.deserialize(res.getBody(), StripeSetupIntentResponseWrapper.class);
            System.debug(res.getBody());
            //System.debug(paymentIntentResponse);
            return paymentIntentResponse;
        } else {
            return null;
        }
    }

    public static StripeMandateResponseWrapper getMandateDetails(String mandateId){
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_MANDATES + '/' + mandateId,
                'GET',
                null);
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripeMandateResponseWrapper mandateResponse = (StripeMandateResponseWrapper) JSON.deserialize(res.getBody(), StripeMandateResponseWrapper.class);
            System.debug(res.getBody());
            //System.debug(paymentIntentResponse);
            return mandateResponse;
        } else {
            return null;
        }
    }
    
    public static StripePaymentMethodResponseWrapper getPaymentMethod(String paymentMethodId){
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_PAYMENT_METHODS + '/' + paymentMethodId, 
                'GET', 
                null);
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripePaymentMethodResponseWrapper paymentMethodResponse = (StripePaymentMethodResponseWrapper) JSON.deserialize(res.getBody(), StripePaymentMethodResponseWrapper.class);
            System.debug(res.getBody());
            //System.debug(paymentIntentResponse);
            return paymentMethodResponse;
        } else {
            return null;
        }
    }
    
    
    //https://stripe.com/docs/api/setup_intents/cancel
    public static StripeSetupIntentResponseWrapper cancelSetupIntent(String setupIntentKey, String reason){
        String body = reason != null ? 'cancellation_reason=' + reason : null;
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_SETUP_INTENTS + '/' + setupIntentKey + '/cancel', 
                'POST',
                body);
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripeSetupIntentResponseWrapper paymentIntentResponse = (StripeSetupIntentResponseWrapper) JSON.deserialize(res.getBody(), StripeSetupIntentResponseWrapper.class);
            System.debug(res.getBody());
            return paymentIntentResponse;
        } else {
            return null;
        }
    }
    
    public static StripePaymentIntentResponseWrapper createPaymentIntent(StripePaymentIntentRequestWrapper intentRequest){
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_PAYMENT_INTENTS,
                'POST',
                intentRequest.serializeWrapper());
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripePaymentIntentResponseWrapper chargeResponse = (StripePaymentIntentResponseWrapper) JSON.deserialize(res.getBody(), StripePaymentIntentResponseWrapper.class);
            System.debug(res.getBody());
            return chargeResponse;
        } else {
            return null;
        }
    }
    
    public static StripePaymentIntentCaptureResponse capturePaymentIntent(String paymentIntentId, Decimal amountToCapture, String currencyIsoCode, Id recordId){
        Decimal amount = StripeUtil.currencyMultiplier(currencyIsoCode) * amountToCapture;
        HttpResponse res = StripeCallouts.doCallout(
                StripeCallouts.URL_PAYMENT_INTENTS + '/' + paymentIntentId + '/capture',
                'POST',
                'amount_to_capture=' + amount.intValue() + '&metadata[payment_reference]=' + recordId);
        if(res.getStatusCode() == 200 || ERROR_CODES.contains(res.getStatusCode())){
            StripePaymentIntentCaptureResponse chargeResponse = (StripePaymentIntentCaptureResponse) JSON.deserialize(res.getBody(), StripePaymentIntentCaptureResponse.class);
            System.debug(res.getBody());
            return chargeResponse;
        } else {
            return null;
        }
    }
}