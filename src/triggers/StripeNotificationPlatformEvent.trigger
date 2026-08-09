//Batch size is set to 5 by below query - use Tooling API to access it (StripeNotificationConfig)
//SELECT Id, BatchSize, DeveloperName, MasterLabel, PlatformEventConsumerId FROM PlatformEventSubscriberConfig
//https://developer.salesforce.com/docs/atlas.en-us.236.0.api_tooling.meta/api_tooling/tooling_api_objects_platformeventsubscriberconfig.htm
trigger StripeNotificationPlatformEvent on Stripe_Notification__e (after insert) {

    if(Trigger.isInsert && Trigger.isAfter){
        StripeNotificationPlatformEventHandler.afterInsert(Trigger.new);
    }
}