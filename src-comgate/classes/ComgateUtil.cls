public with sharing class ComgateUtil {
    public static Boolean runningInASandbox {
        get {
            //check if boolean has been set yet
            if (runningInASandbox == null) {
                runningInASandbox = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
            }
            //Return value
            return runningInASandbox;
        }
        set;
    }

    public static Comgate_Settings__c comgateSettings {
        get {
            if (comgateSettings == null) {
                comgateSettings = Comgate_Settings__c.getOrgDefaults();
            }
            return comgateSettings;
        }
        set;
    }

    public static String convertComgatePaymentMethod(String comgatePaymentMethod){
        if(comgatePaymentMethod.startsWith('CARD')) return 'Credit Card';
        if(comgatePaymentMethod.startsWith('BANK')) return 'Online Bank';

        switch on comgatePaymentMethod{
            when 'GPAY'{
                return 'Google Pay';
            }
            when 'APPLEPAY'{
                return 'Apple Pay';
            }
            when 'TRANSFER'{
                return 'Bank Transfer';
            }
        }
        return comgatePaymentMethod;
    }
}