public without sharing class DonationPageController {

    @TestVisible private class DonationPageControllerException extends Exception{}

    @AuraEnabled
    public static String getFieldSetWrapper(String fieldSetName, Id contactId){
        Map<String, Object> returnMap = new Map<String, Object>();
        FieldSet fieldSet = Contact.SObjectType.getDescribe().fieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) throw new DonationPageControllerException('Field set not found!');

        List<FieldSetWrapper> wrappers = new List<FieldSetWrapper>();
        List<String> fieldStrings = new List<String>();
        for(FieldSetMember fs : fieldSet.getFields()){
            wrappers.add(new FieldSetWrapper(fs));
            fieldStrings.add(fs.getFieldPath());
        }
        returnMap.put('fieldSetWrapper', wrappers);
        returnMap.put('contact', getFieldSetContact(contactId, fieldStrings));
        return JSON.serialize(returnMap);
    }

    public static Contact getFieldSetContact(Id recordId, List<String> fieldStrings){
        if(recordId == null) return null;
        String query = 'SELECT Id ';
        if(!fieldStrings.isEmpty()) query += ',' + String.join(fieldStrings, ',');
        query += ' FROM Contact WHERE Id =: recordId';

        List<Contact> contacts = Database.query(query);
        if(contacts.isEmpty()) return null;
        return contacts[0];
    }

    @AuraEnabled
    public static String getPaymentReference(String conString, String campaignId, String paymentWrapperString){
        Map<String, Object> returnMap = new Map<String, Object>();
        Contact con = (Contact) JSON.deserialize(conString, Contact.class);
        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);
        if(paymentWrapper?.privacyAgreement == true) throw new DonationPageControllerException('Your payment request cannot be processed, please contact our support services.');

        con = processContact(con);
        returnMap.put('shopperReferenceId', con.Id);
        returnMap.put('paymentReferenceId', createPaymentReference(conString, paymentWrapperString, campaignId, con.Id));
        return JSON.serialize(returnMap);
    }

    @AuraEnabled
    public static String createComgatePayment(String conString, String campaignId, String paymentWrapperString){
        Contact con = (Contact) JSON.deserialize(conString, Contact.class);
        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);
        if(paymentWrapper?.privacyAgreement == true) throw new DonationPageControllerException('Your payment request cannot be processed, please contact our support services.');
        ComgatePaymentRequestWrapper paymentRequestWrapper = new ComgatePaymentRequestWrapper(paymentWrapper, con);

        Campaign campaign = getCampaignDetails(campaignId);
        if(campaign?.Comgate_Bank_Account__c != null) paymentRequestWrapper.account = campaign.Comgate_Bank_Account__c;

        System.debug(paymentRequestWrapper);
        ComgatePaymentResponseWrapper paymentResponseWrapper = ComgateService.getPayment(paymentRequestWrapper);
        return paymentResponseWrapper.redirect;
    }

    private static Campaign getCampaignDetails(String campaignId){
        if(campaignId != null || !(campaignId instanceof Id)) return null;

        List<Campaign> campaigns = [SELECT Id, Comgate_Bank_Account__c FROM Campaign WHERE Id = :campaignId];
        if(campaigns.isEmpty()) return null;
        return campaigns[0];
    }

    @AuraEnabled
    public static Map<String, Object> justCreateRecords(String conString, String campaignId, String paymentWrapperString){
        List<Campaign> campaigns = [SELECT Id, Comgate_Bank_Account__c, Bank_Account__c,
                Bank_Account__r.IBAN__c, Bank_Account__r.Bank_Account_Number__c FROM Campaign WHERE Id =: campaignId];
        Campaign campaign = campaigns.isEmpty() ? null : campaigns[0];
        Contact con = (Contact) JSON.deserialize(conString, Contact.class);
        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);

        processContact(con);
        Id donationRecordId = prepareDonationRecord(con, paymentWrapper, campaignId);
        String comgateVar = getComgateVariable(donationRecordId);

        return new Map<String, Object>{
          'bankAccountNumber' => campaign?.Bank_Account__r.Bank_Account_Number__c ?? 'XXX-XXXXXXXX/XXX',
          'iban' => campaign?.Bank_Account__r.IBAN__c ?? 'XXX-XXXXXXXX/XXX',
          'variableNumber' => comgateVar,
          'qrPayload' => getQrPayload(paymentWrapper, comgateVar, campaign.Bank_Account__r)
        };
    }

    //https://developer.mastercard.com/mastercard-checkout-solutions/documentation/use-cases/sqr/generate-qr-codes/
    private static String getQrPayload(DonationPagePaymentWrapper paymentWrapper, String comgateVar, Bank_Account__c bankAccount){
        String qrPayload = '';
        qrPayload += 'SPD*1.0*ACC:' + bankAccount.IBAN__c;
        qrPayload += '*AM:' + paymentWrapper.donationValue;
        qrPayload += '*CC:' + paymentWrapper.currencyIsoCode;
        qrPayload += '*X-VS:' + comgateVar;

        return qrPayload;
    }

    private static String getComgateVariable(Id recordId){
        List<Opportunity> opportunities = [SELECT Comgate_Variable_Symbol__c FROM Opportunity WHERE Id =: recordId];
        if(!opportunities.isEmpty()) return opportunities[0].Comgate_Variable_Symbol__c;

        List<npe03__Recurring_Donation__c> recurringDonations = [SELECT Comgate_Variable_Symbol__c FROM npe03__Recurring_Donation__c WHERE Id =: recordId];
        if(!recurringDonations.isEmpty()) return recurringDonations[0].Comgate_Variable_Symbol__c;

        return 'ERROR';

    }

    @AuraEnabled
    public static void createRelatedRecords(Id paymentReferenceId, Id shopperReferenceId){
        Payment_Reference__c paymentReference = [SELECT Id, JSON_Contact__c, JSON_Payment_Wrapper__c, CampaignId__c, Contact__c,
                Contact__r.FirstName, Contact__r.LastName, Contact__r.AccountId
        FROM Payment_Reference__c WHERE Id =: paymentReferenceId];

        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentReference.JSON_Payment_Wrapper__c, DonationPagePaymentWrapper.class);

        Id donationRecordId = prepareDonationRecord(paymentReference.Contact__r, paymentWrapper, paymentReference.CampaignId__c);
        if(donationRecordId.getSobjectType() == Opportunity.SObjectType){
            paymentReference.Opportunity__c = donationRecordId;
        } else {
            paymentReference.Recurring_Donation__c = donationRecordId;
        }
        update paymentReference;
    }

    public static Id createPaymentReference(String conString, String paymentWrapperString, String campaignId, Id contactId){
        Payment_Reference__c paymentReference = new Payment_Reference__c();
        paymentReference.JSON_Contact__c = conString;
        paymentReference.JSON_Payment_Wrapper__c = paymentWrapperString;
        paymentReference.CampaignId__c = campaignId;
        paymentReference.Contact__c = contactId;
        insert paymentReference;
        return paymentReference.Id;
    }

    private static Id prepareDonationRecord(Contact con, DonationPagePaymentWrapper paymentWrapper, String campaignId){
        campaignId = campaignId != null && campaignId instanceof Id ? campaignId : null; //Check if campaignId is valid
        if(paymentWrapper.donationType != 'oneoff'){
            npe03__Recurring_Donation__c rec = new npe03__Recurring_Donation__c();
            rec.Name = con.FirstName + ' ' + con.LastName + ' Recurring Donation';
            rec.Payment_Method__c = convertPaymentMethodValue(paymentWrapper.paymentOption);
            rec.npe03__Contact__c = con.Id;
            rec.npe03__Amount__c = paymentWrapper.donationValue;
            rec.CurrencyIsoCode = paymentWrapper.currencyIsoCode;
            rec.npe03__Date_Established__c = Date.today();
            rec.npe03__Open_Ended_Status__c = 'Open';
            rec.Comgate_Recurring__c = true;
            rec.npe03__Recurring_Donation_Campaign__c = campaignId;
            rec.npe03__Installment_Period__c = getInstallmentPeriod(paymentWrapper.donationType);
            insert rec;
            return rec.Id;
        } else {
            Opportunity opp = new Opportunity();
            opp.Name = con.FirstName + ' ' + con.LastName + ' One-Off Donation ' + Datetime.now().format('dd.MM.YYYY');
            opp.ContactId = con.Id;
            opp.Payment_Method__c = convertPaymentMethodValue(paymentWrapper.paymentOption);
            opp.StageName = 'Pledged';
            opp.CampaignId = campaignId;
            opp.AccountId = con.AccountId;
            opp.CurrencyIsoCode = paymentWrapper.currencyIsoCode;
            opp.Amount = paymentWrapper.donationValue;
            opp.CloseDate = Date.today();
            insert opp;
            return opp.Id;
        }
    }

    private static String getInstallmentPeriod(String donationType){
        switch on donationType{
            when 'recurring_yearly'{
                return 'Yearly';
            }
            when 'recurring_monthly'{
                return 'Monthly';
            }
            when 'recurring_quarterly'{
                return 'Quarterly';
            }
        }
        return null;
    }

    //Check if the contact already exist - otherwise create new one
    private static Contact processContact(Contact con){
        Contact existingContact;
        if(con.Id == null) {
            List<Contact> contacts = [SELECT Id, AccountId FROM Contact
                WHERE Email = :con.Email  ORDER BY CreatedDate ASC LIMIT 1];
            if(!contacts.isEmpty()) {
                existingContact = contacts[0];
                con.Id = existingContact.Id;
                con.AccountId = existingContact.AccountId;
            }
        }

        if(con.Id != null) con = checkExistingContactId(con);

        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.duplicateRuleHeader.allowSave = true;


        if(con.Id == null){
            con.LeadSource = 'Donation Page';
            Database.insert(con, dmlOptions);

            Contact conAfter = [SELECT Id, AccountId FROM Contact WHERE Id = :con.Id];
            con.AccountId = conAfter.AccountId;
        } else {
            Database.update(con, dmlOptions);
        }
        return con;
    }

    private static Contact checkExistingContactId(Contact con){
        List<Contact> contacts = [SELECT Id, AccountId, Email, LastName
            FROM Contact WHERE  Id = :con.Id  ORDER BY CreatedDate ASC LIMIT 1];
        if(contacts.isEmpty()) return con;

        Contact existingContact = contacts[0];
        if(existingContact.Email == con.Email && existingContact.LastName != con.LastName){
            throw new DonationPageControllerException('The contact details on this form have been fixed to the person receiving an email and ' +
                    'cannot be updated.');
        } else if (existingContact.Email != con.Email && existingContact.LastName != con.LastName){
            con = con.clone(false);
        } else {
            con.AccountId = existingContact.AccountId;
        }
        return con;
    }

    public static String convertPaymentMethodValue(String inputMethod){
        switch on inputMethod{
            when 'paypal'{
                return 'PayPal';
            }
            when 'card','visa','mc'{
                return 'Credit Card';
            }
            when 'bankTransfer'{
                return 'Bank Transfer';
            }
            when else {
                return inputMethod;
            }
        }
    }
}