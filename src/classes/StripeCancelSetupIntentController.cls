/**
 * Created by LukášGregora on 19/12/2023.
 */

public with sharing class StripeCancelSetupIntentController {

    @AuraEnabled
    public static void cancelSetupIntent(String reason, String giftCommitmentId){
        if(reason == null) throw new AuraHandledException('Missing cancellation reason!');
        Payment_Log__c paymentLog = getPaymentLog(giftCommitmentId);
        if(paymentLog.Setup_Intent__c == null) throw new AuraHandledException('Related payment log is missing setup intent id!');
        
        StripeSetupIntentResponseWrapper setupIntentResponse = StripeService.cancelSetupIntent(paymentLog.Setup_Intent__c, reason);
        if(setupIntentResponse == null) throw new AuraHandledException('Request to cancel stripe recurring donation failed!');
        if(setupIntentResponse?.error?.message != null) throw new AuraHandledException('Request to cancel stripe recurring donation failed! Reason: ' + setupIntentResponse.error.message);
        closeRecurring(giftCommitmentId, reason);
    }
    
    private static Payment_Log__c getPaymentLog(String giftCommitmentId){
        List<Payment_Log__c> paymentLogs = [SELECT Id, Setup_Intent__c FROM Payment_Log__c
        WHERE Event_Code__c = 'checkout.session.completed'
        AND Payment_Reference__r.Gift_Commitment__c =: giftCommitmentId
        ORDER BY CreatedDate ASC];
        if(paymentLogs.isEmpty()) throw new AuraHandledException('Missing checkout session for the payment reference!');
        return paymentLogs[0];
    }
    
    private static void closeRecurring(String giftCommitmentId, String reason){
        update new GiftCommitment(
                Id = giftCommitmentId,
                Status = 'Closed',
                Description = reason
        );
    }
}