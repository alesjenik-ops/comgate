public with sharing class StripeMockTest {
    public final static String PAYMENT_INTENT_ID = 'pi_3MtwBwLkdIwHu7ix28a3tqPa';
    public final static String PAYMENT_METHOD_ID = 'pm_1Mm2cBLkdIwHu7ixGoOfZSsV';
    public final static String SETUP_INTENT_ID = 'seti_1Mm8s8LkdIwHu7ix0OXBfTRG';
    public final static String MANDATE_ID = 'mandate_1MvojA2eZvKYlo2CvqTABjZs';
    public final static String MANDATE_REFERENCE = '123456789';
    public final static String CHECKOUT_SESSION_ID = 'cs_test_a11YYufWQzNY63zpQ6QSNRQhkUpVph4WRmzW0zWJO2znZKdVujZ0N0S22u';
    public final static String CUSTOMER_ID = 'customer_id';
    public final static String ERROR_MESSAGE = 'Error on server side';
    
    public class DummyMock implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody('');
            res.setStatusCode(200);
            return res;
        }
    }

    public class CancelSetupIntent implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + SETUP_INTENT_ID + '",' +
                            '"payment_method": null,' +
                            '"payment_method_types": ["card"]}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class PaymentIntentFull implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            if(req.getEndpoint().contains(StripeCallouts.URL_SETUP_INTENTS)){
                return new GetSetupIntent().respond(req);
            } else if (req.getEndpoint().endsWith(StripeCallouts.URL_PAYMENT_INTENTS)){
                return new CreatePaymentIntent().respond(req);
            } else if (req.getEndpoint().contains(StripeCallouts.URL_PAYMENT_INTENTS) 
                    && req.getEndpoint().contains('/capture')){
                return new CapturePaymentIntent().respond(req);
            }else if (req.getEndpoint().contains(StripeCallouts.URL_PAYMENT_METHODS)){
                return new PaymentMethodResponse().respond(req);
            }else if (req.getEndpoint().contains(StripeCallouts.URL_MANDATES)){
                return new MandateResponse().respond(req);
            }
            return null;
        }
    }

    public class GetSetupIntent implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + SETUP_INTENT_ID + '",' +
                            '"payment_method": "' + PAYMENT_METHOD_ID + '",' +
                            '"mandate": "' + MANDATE_ID + '",' +
                            '"payment_method_types": ["card"]}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class PaymentMethodResponse implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + PAYMENT_METHOD_ID + '","type": "card"}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class MandateResponse implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + MANDATE_ID + '","payment_method_details": {"sepa_debit" : {"reference" : "' + MANDATE_REFERENCE+ '"}}}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class ErrorResponse implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + SETUP_INTENT_ID + '",' +
                            '"payment_method": "' + PAYMENT_METHOD_ID + '",' +
                            '"payment_method_types": ["card"], ' +
                            '"error" : {"type":"api_error", "message":"' + ERROR_MESSAGE + '"}}'
            );
            res.setStatusCode(400);
            return res;
        }
    }


    public class CreatePaymentIntent implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + PAYMENT_INTENT_ID + '"}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class CapturePaymentIntent implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"amount": 1000, "amount_received": 1000, "status": "succeeded"}'
            );
            res.setStatusCode(200);
            return res;
        }
    }

    public class CreateCheckoutSessionResponse implements HttpCalloutMock{
        public HttpResponse respond(HttpRequest req){
            HttpResponse res = new HttpResponse();
            res.setBody(
                    '{"id": "' + CHECKOUT_SESSION_ID + '", ' +
                            '"object": "checkout.session",' +
                            '"status": "open",' +
                            '"amount": 1000,' +
                            '"client_secret": "TEST123",' +
                            '"return_url": "http://test.test",' +
                            '"livemode": false}'
            );
            res.setStatusCode(200);
            return res;
        }
    }
}