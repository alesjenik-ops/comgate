public with sharing class ComgateCallouts {
    public final static String URL_PAYMENT = '/v2.0/payment.json';
    public final static String URL_RECURRING = '/v2.0/recurring.json';
    public final static String URL_PAYMENT_STATUS = '/v2.0/payment/transId/';

    private class ComgateCalloutsException extends Exception{}

    public static HttpResponse doCallout(String url, String method, String body){
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ComgatePaymentsNamed' + url);
        req.setMethod(method);
        if(body != null) req.setBody(body);
        req.setHeader('Content-Type', 'application/json');

        System.debug(req.getBody());

        HttpResponse res = new Http().send(req);
        System.debug(res);
        System.debug(res.getBody());
        return res;
    }
}