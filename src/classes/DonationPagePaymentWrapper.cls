/**
 * Created by LukášGregora on 10/01/2024.
 */

public with sharing class DonationPagePaymentWrapper {
    @AuraEnabled public String donationType; //One-Off / Recurrent
    @AuraEnabled public Decimal donationValue;
    @AuraEnabled public String paymentOption; //IBAN, Card, Paypal
    @AuraEnabled public String[] allowedPaymentMethods; //From front end
    @AuraEnabled public String redirectURL;
    @AuraEnabled public String currencyIsoCode;
    @AuraEnabled public String leadSource;
    @AuraEnabled public Id referenceId; //Id of the opportunity/recurring donation
    @AuraEnabled public Boolean privacyAgreement; //honeypot field
}