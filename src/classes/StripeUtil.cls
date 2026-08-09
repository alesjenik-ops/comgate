/**
 * Created by LukášGregora on 23/11/2023.
 */

public with sharing class StripeUtil {
    public static final String DEFAULT_CURRENCY = 'CZK';
    public static final String GIFT_TRANSACTION_PAID = 'Paid';
    public static final String GIFT_TRANSACTION_UNPAID = 'Unpaid';
    public static final String GIFT_TRANSACTION_FAILED = 'Failed';

    public static Stripe_Settings__c stripeSettings {
        get {
            if (stripeSettings == null) {
                stripeSettings = Stripe_Settings__c.getOrgDefaults();
            }
            return stripeSettings;
        }
        set;
    }

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

    public static Id getPersonAccountRecordTypeId {
        get {
            if (getPersonAccountRecordTypeId == null) {
                getPersonAccountRecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('PersonAccount').getRecordTypeId();
            }
            return getPersonAccountRecordTypeId;
        }
        set;
    }
    

    public static String getDateFromUTCStamp(Long utcTimestamp) {
        try {
            return Datetime.newInstance(Long.valueOf(utcTimestamp + '000')) + '';
        } catch (Exception e) {
            return '';
        }
    }
    

    //https://stripe.com/docs/currencies
    public static Decimal currencyMultiplier(String currencyIsoCode) {
        switch on (currencyIsoCode) {
            //Zero Decimal currencies
            when 'BIF', 'CLP', 'DJF', 'GNF', 'JPY', 'KMF', 'KRW', 'MGA',
                    'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF' {
                return 1;
            }

            //Three Decimal currencies
            when 'BHD', 'JOD', 'KWD', 'OMR', 'TND' {
                return 1000;
            }

            when else {
                return 100;
            }
        }
    }

    public static String getOneMessage(String firstOne, String secondOne) {
        if (firstOne != null) return firstOne;
        return secondOne;
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
    
    public static String convertStripePaymentMethod(String input){
        if(input == null) return '';
        switch on (input){
            when 'card'{
                return 'CreditCard';
            }
            when 'paypal'{
                return 'PayPal';
            }
            when 'sepa_debit','sepa'{
                return 'SEPA Direct Debit';
            }
            when else {
                return '';
            }
        }
    }
    
    public static Boolean isIdValid(String inputValue){
        try{
            ((Id) inputValue).getSobjectType();
            return true;
        } catch (Exception e){
            return false;
        }
    }

    public static void setDonationStatus(GiftTransaction giftTransaction, String status, String message, Decimal currentAttempt){
        giftTransaction.Status__c = status;
        giftTransaction.Status_Reason__c = message;
        giftTransaction.Last_Attempt_Date__c = Datetime.now();

        if(giftTransaction.Status__c != 'ERROR') return;
        giftTransaction.Attempt_Counter__c = currentAttempt > 0 ? currentAttempt+1 : 1;
    }
}