public with sharing class StripePaymentFormController {

    @AuraEnabled(Cacheable=true)
    public static String getStripePublicKey(){
        return StripeUtil.stripeSettings.Public_Key__c;
    }


    @AuraEnabled
    public static void updatePaymentReferenceWithRadarId(Id paymentReferenceId, String radarSession){
        List<Payment_Reference__c> paymentReferences = [SELECT Id, Radar_Session_Id__c FROM Payment_Reference__c WHERE Id =: paymentReferenceId];
        System.debug(paymentReferences);
        if(paymentReferences.size() == 0) return;

        paymentReferences[0].Radar_Session_Id__c = radarSession;
        update paymentReferences[0];
    }
}