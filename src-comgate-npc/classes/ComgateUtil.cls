public with sharing class ComgateUtil {
    public static final String DEFAULT_CURRENCY = 'CZK';
    public static final String GIFT_TRANSACTION_PAID = 'Paid';
    public static final String GIFT_TRANSACTION_UNPAID = 'Unpaid';
    public static final String GIFT_TRANSACTION_FAILED = 'Failed';

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

    // test payments: always in a sandbox, in production only with Comgate_Settings__c.Test_Mode__c checked
    public static Boolean isTestPayment {
        get {
            return runningInASandbox || comgateSettings.Test_Mode__c == true;
        }
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

    public static Id getPersonAccountRecordTypeId {
        get {
            if (getPersonAccountRecordTypeId == null) {
                getPersonAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
            }
            return getPersonAccountRecordTypeId;
        }
        set;
    }

    public static String convertComgatePaymentMethod(String comgatePaymentMethod){
        if(comgatePaymentMethod == null) return null;
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

    public static Boolean isIdValid(String inputValue){
        try{
            ((Id) inputValue).getSobjectType();
            return true;
        } catch (Exception e){
            return false;
        }
    }

    public static Boolean checkIfAlreadyScheduled(String jobName) {
        return [SELECT Id,
                        CronJobDetail.Name,
                        CronJobDetail.Id,
                        State
                FROM CronTrigger
                WHERE CronJobDetail.Name = :jobName
                AND State != 'COMPLETE'
        ].isEmpty();
    }

    public static void setDonationStatus(GiftTransaction giftTransaction, String status, String message, Decimal currentAttempt){
        giftTransaction.Status__c = status;
        giftTransaction.Status_Reason__c = message;
        giftTransaction.Last_Attempt_Date__c = Datetime.now();

        if(giftTransaction.Status__c != 'ERROR') return;
        giftTransaction.Attempt_Counter__c = currentAttempt > 0 ? currentAttempt+1 : 1;
    }
}
