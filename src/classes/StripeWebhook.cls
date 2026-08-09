@RestResource(UrlMapping='/stripewebhook')
global without sharing class StripeWebhook {

    //So far processing AUTHORISATION, CAPTURE
    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse resp = RestContext.response;

        System.debug(req.requestBody);
        System.debug(req.requestBody.toString());
        
        //https://stackoverflow.com/questions/51347704/stripe-verify-web-hook-signature-hmac-sha254-hapi-js
        //https://stackoverflow.com/questions/68288698/how-to-verify-stripes-webhook-signature
        System.debug(getHmacSignature(req));
        System.debug(req.requestBody.toString());
        if(!checkHmac(getHmacSignature(req), req.requestBody.toString())){
            resp.statusCode = 200; //Unauthorized
            return;
        }


        StripeWebhookWrapper notification = new StripeWebhookWrapper().deserializeJSON(req.requestBody.toString());


        List<Stripe_Notification__e> notifications = new List<Stripe_Notification__e>();
        List<Payment_Log__c> logs = new List<Payment_Log__c>();

        //How to get connection to Session from the Charge webhook
        //https://stackoverflow.com/questions/67182230/how-do-you-match-a-stripe-checkout-to-a-charge-succeeded-webhook

        notifications.add(new Stripe_Notification__e(
                Type__c = notification.type,
                Status__c = notification.data?.object_x?.status,
                Reason__c = notification.data?.object_x?.reason,
                Amount_Captured__c = notification.data?.object_x?.amount_captured,
                Payment_Method__c = notification.getPaymentMethod(),
                Stripe_Customer_Id__c = notification.data?.object_x?.customer,
                Payment_Reference_Id__c = notification.getDonationReference(),
                Payment_Intent__c = notification.data?.object_x?.payment_intent
        ));
        logs.add(notification.getPaymentLog());

        new ExecuteWithoutSharing().insertLogs(logs);

        publishPlatformEvents(notifications);

        resp.statusCode = 200;
        resp.responseBody = Blob.valueOf('[accepted]');
    }

    private static String getHmacSignature(RestRequest req){
        return req.headers.get('signature') ?? req.headers.get('stripe-signature') ?? req.headers.get('Stripe-Signature');
    }
    

    private static void publishPlatformEvents(List<SObject> notifications){
        List<Database.SaveResult> results = EventBus.publish(notifications);

        // Inspect publishing result for each event
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                System.debug('Successfully published event.');
            } else {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('Error returned: ' +
                            err.getStatusCode() +
                            ' - ' +
                            err.getMessage());
                }
            }
        }
    }

    @TestVisible
    private static Boolean checkHmac(String stripeSignature, String requestBody){
        Map<String, String> scrapStripeSignature = scrapStripeSignature(stripeSignature);
        String signed_payload = scrapStripeSignature.get('t') + '.' + requestBody;
        return verifyHMACMessage(signed_payload, scrapStripeSignature.get('v1'));
    }

    private static Boolean verifyHMACMessage(String hmacMessage, String hmacSignature){
        String secret = StripeUtil.stripeSettings.HMAC_Signature__c; // this is the shared secret
        EncodingUtil.base64Decode(hmacSignature);
        Blob.valueOf(hmacMessage);
        System.debug(Crypto.verifyHmac('hmacSHA256',Blob.valueOf(hmacMessage),Blob.valueOf(secret),EncodingUtil.base64Decode(hmacSignature)));
// If `secret` is a hexadecimal string, I believe you'll need to do `EncodingUtil.convertFromHex()` here, 
// unless the remote system is just treating it as ASCII text.
        Blob hmac = Crypto.generateMac('hmacSHA256', Blob.valueOf(hmacMessage), Blob.valueOf(secret));
        System.debug(secret);
        System.debug(hmacMessage);
        System.debug(hmacSignature);
        System.debug(EncodingUtil.convertToHex(hmac));
        System.debug(EncodingUtil.base64Encode(hmac));
        System.debug(String.valueOf(EncodingUtil.convertToHex(hmac)));
        System.debug(hmac);
        System.debug(hmac == EncodingUtil.base64Decode(hmacSignature));
        System.debug(hmac == EncodingUtil.convertFromHex(hmacSignature));
        System.debug(hmac == Blob.valueOf(hmacSignature));

        return Crypto.verifyHmac('hmacSHA256',Blob.valueOf(hmacMessage),Blob.valueOf(secret),EncodingUtil.convertFromHex(hmacSignature));
    }
    
    private static Map<String, String> scrapStripeSignature(String stripeSignature){
        Map<String, String> returnMap = new Map<String, String>();
        for(String stripeSignatureItem : stripeSignature.split(',')){
            List<String> stripeSignatureItemSplit = stripeSignatureItem.split('=');
            returnMap.put(stripeSignatureItemSplit[0], stripeSignatureItemSplit[1]);
        }
        return returnMap;
    }


    private without sharing class ExecuteWithoutSharing{
        public void insertLogs(List<Payment_Log__c> logs){
            insert logs;
        }
    }
}