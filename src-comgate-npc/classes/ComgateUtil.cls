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

    //Comgate reports the method actually used (GOOGLEPAY, APPLEPAY, CARD_CZ_COMGATE, BANK_CZ_KB, LATER_TWISTO...).
    //Payment_Method__c on GiftTransaction and GiftCommitment is a restricted picklist bound to the
    //Payment_Method global value set, so anything we cannot map has to stay null - otherwise the DML
    //fails with INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST and the webhook answers 500.
    //The raw code is still kept on Payment_Log__c.Payment_Method__c.
    public static String convertComgatePaymentMethod(String comgatePaymentMethod){
        if(String.isBlank(comgatePaymentMethod)) return null;

        String methodCode = comgatePaymentMethod.trim().toUpperCase();

        if(methodCode.startsWith('GOOGLEPAY') || methodCode.startsWith('GPAY')) return 'Google Pay';
        if(methodCode.startsWith('APPLEPAY')) return 'Apple Pay';
        if(methodCode.startsWith('CARD')) return 'Credit Card';
        if(methodCode.startsWith('TRANSFER')) return 'Bank Transfer';
        if(methodCode.startsWith('BANK')) return 'Online Bank';

        return null;
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
