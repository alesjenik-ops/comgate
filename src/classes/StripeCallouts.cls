public with sharing class StripeCallouts {
    public final static String URL_PAYMENT_INTENTS = '/payment_intents';
    public final static String URL_SETUP_INTENTS = '/setup_intents';
    public final static String URL_CHECKOUT_SESSION = '/checkout/sessions';
    public final static String URL_PAYMENT_METHODS = '/payment_methods';
    public final static String URL_MANDATES = '/mandates';
    private class StripeCalloutsException extends Exception{}

    public static HttpResponse doCallout(String url, String method, String body){
        HttpRequest req = new HttpRequest();
        if(StripeUtil.runningInASandbox){
            req.setEndpoint('callout:Stripe_DEV' + url);
        } else {
            req.setEndpoint('callout:Stripe_PROD' + url);
        }
        req.setMethod(method);
        if(body != null) req.setBody(body);
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        System.debug(req.getBody());

        HttpResponse res = new Http().send(req);
        System.debug(res);
        System.debug(res.getBody());
        return res;
    }
}