public without sharing class DonationPageController {

    @TestVisible private class DonationPageControllerException extends Exception{}

    @AuraEnabled
    public static String getFieldSetWrapper(String fieldSetName, Id donorId, Id campaignId){
        Map<String, Object> returnMap = new Map<String, Object>();
        FieldSet fieldSet = Account.SObjectType.getDescribe().fieldSets.getMap().get(fieldSetName);
        if(fieldSet == null) throw new DonationPageControllerException('Field set not found!');

        List<FieldSetWrapper> wrappers = new List<FieldSetWrapper>();
        List<String> fieldStrings = new List<String>();
        for(FieldSetMember fs : fieldSet.getFields()){
            wrappers.add(new FieldSetWrapper(fs));
            fieldStrings.add(fs.getFieldPath());
        }
        returnMap.put('fieldSetWrapper', wrappers);
        returnMap.put('donor', getFieldSetDonor(donorId, fieldStrings));
        returnMap.put('campaigns', getDonationCampaigns(campaignId));
        returnMap.put('countryOptions', PicklistValue.getPicklistValues(Account.Country__c.getDescribe().getPicklistValues()));
        return JSON.serialize(returnMap);
    }

    private static List<Campaign> getDonationCampaigns(Id campaignId){
        return [SELECT Id, Name, Donation_Page_Thank_You_Text__c FROM Campaign WHERE Donation_Page_Visible__c = TRUE
            OR Id = :campaignId];
    }

    @AuraEnabled(Cacheable=true)
    public static Campaign getCampaignDetail(Id recordId){
        return [SELECT Id, Name, Donation_Page_Detail__c FROM Campaign WHERE Id = :recordId];
    }

    public static Account getFieldSetDonor(Id recordId, List<String> fieldStrings){
        if(recordId == null) return null;
        String query = 'SELECT Id ';
        if(!fieldStrings.isEmpty()) query += ',' + String.join(fieldStrings, ',');
        query += ' FROM Account WHERE Id =: recordId';

        List<Account> accounts = Database.query(query);
        if(accounts.isEmpty()) return null;
        return accounts[0];
    }

    @AuraEnabled
    public static String getReferenceId(String donorString, String conString, String campaignId,
            String paymentWrapperString, Boolean isPersonAccount){
        Map<String, Object> returnMap = new Map<String, Object>();
        Account donor = (Account) JSON.deserialize(donorString, Account.class);
        Contact con = (Contact) JSON.deserialize(conString, Contact.class);

        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);
        if(paymentWrapper?.privacyAgreement == true) throw new DonationPageControllerException('Your payment request cannot be processed, please contact our support services.');
        donor = processDonor(donor, con, isPersonAccount);
        returnMap.put('shopperReference', donor.Id);
        returnMap.put('paymentReference', createPaymentReference(donorString, paymentWrapperString, campaignId, donor.Id));
        return JSON.serialize(returnMap);
    }

    @AuraEnabled
    public static String createComgatePayment(Id paymentReferenceId, String donorString, String campaignId, String paymentWrapperString){
        Account donor = (Account) JSON.deserialize(donorString, Account.class);
        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);
        if(paymentWrapper?.privacyAgreement == true) throw new DonationPageControllerException('Your payment request cannot be processed, please contact our support services.');
        paymentWrapper.paymentReferenceId = paymentReferenceId;

        Campaign campaign = getCampaignDetails(campaignId);
        ComgatePaymentRequestWrapper paymentRequestWrapper = new ComgatePaymentRequestWrapper(paymentWrapper, donor, campaign?.Name ?? 'Dar');
        if(campaign?.Comgate_Bank_Account__c != null) paymentRequestWrapper.account = campaign.Comgate_Bank_Account__c;

        System.debug(paymentRequestWrapper);
        ComgatePaymentResponseWrapper paymentResponseWrapper = ComgateService.getPayment(paymentRequestWrapper);
        return paymentResponseWrapper.redirect;
    }

    private static Campaign getCampaignDetails(String campaignId){
        if(campaignId == null || !(campaignId instanceof Id)) return null;

        List<Campaign> campaigns = [SELECT Id, Name, Comgate_Bank_Account__c FROM Campaign WHERE Id = :campaignId];
        if(campaigns.isEmpty()) return null;
        return campaigns[0];
    }

    @AuraEnabled
    public static void createRelatedRecords(Id paymentReferenceId, Id shopperReferenceId){
        Payment_Reference__c paymentReference = [SELECT Id, JSON_Account__c, JSON_Payment_Wrapper__c, CampaignId__c, Account__c,
                Account__r.FirstName, Account__r.LastName, Account__r.Name
        FROM Payment_Reference__c WHERE Id =: paymentReferenceId];

        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentReference.JSON_Payment_Wrapper__c, DonationPagePaymentWrapper.class);

        Id donationRecordId = prepareDonationRecord(paymentReference.Account__r, paymentWrapper, paymentReference.CampaignId__c, null);
        if(donationRecordId.getSobjectType() == GiftTransaction.SObjectType){
            paymentReference.Gift_Transaction__c = donationRecordId;
        } else {
            paymentReference.Gift_Commitment__c = donationRecordId;
        }
        update paymentReference;
    }

    @AuraEnabled
    public static Map<String, Object> justCreateRecords(String donorString, String conString,
            String campaignId, String paymentWrapperString, Boolean isPersonAccount){
        List<Campaign> campaigns = [SELECT Id, Bank_Account__c,
                Bank_Account__r.IBAN__c, Bank_Account__r.Bank_Account_Number__c FROM Campaign WHERE Id =: campaignId];
        Campaign campaign = campaigns.isEmpty() ? null : campaigns[0];
        Account donor = (Account) JSON.deserialize(donorString, Account.class);
        Contact con = (Contact) JSON.deserialize(conString, Contact.class);

        DonationPagePaymentWrapper paymentWrapper = (DonationPagePaymentWrapper) JSON.deserialize(paymentWrapperString, DonationPagePaymentWrapper.class);

        Bank_Account__c bankAccount = campaign?.Bank_Account__r ?? [SELECT Id, Bank_Account_Number__c, IBAN__c FROM Bank_Account__c WHERE Default__c = TRUE];

        processDonor(donor, con, isPersonAccount);
        Id donationRecordId = prepareDonationRecord(donor, paymentWrapper, campaignId, bankAccount);
        String comgateVar = getPaymentVariable(donationRecordId);

        return new Map<String, Object>{
                'bankAccountNumber' => bankAccount.Bank_Account_Number__c ?? 'XXX-XXXXXXXX/XXX',
                'iban' => bankAccount.IBAN__c ?? 'XXX-XXXXXXXX/XXX',
                'variableNumber' => comgateVar,
                'qrPayload' => getQrPayload(paymentWrapper, comgateVar, bankAccount)
        };
    }

    //https://developer.mastercard.com/mastercard-checkout-solutions/documentation/use-cases/sqr/generate-qr-codes/
    private static String getQrPayload(DonationPagePaymentWrapper paymentWrapper, String comgateVar, Bank_Account__c bankAccount){
        String qrPayload = '';
        qrPayload += 'SPD*1.0';
        qrPayload += '*ACC:' + bankAccount.IBAN__c;
        qrPayload += '*AM:' + paymentWrapper.donationValue;
        qrPayload += '*CC:' + paymentWrapper.currencyIsoCode;
        qrPayload += '*X-VS:' + comgateVar;

        return qrPayload;
    }

    private static String getPaymentVariable(Id recordId){
        List<GiftTransaction> giftTransactions = [SELECT Comgate_Variable_Symbol__c
            FROM GiftTransaction WHERE Id =: recordId];
        if(!giftTransactions.isEmpty()) return giftTransactions[0].Comgate_Variable_Symbol__c;

        List<GiftCommitment> giftCommitments = [SELECT Comgate_Variable_Symbol__c FROM GiftCommitment WHERE Id =: recordId];
        if(!giftCommitments.isEmpty()) return giftCommitments[0].Comgate_Variable_Symbol__c;

        return 'ERROR';

    }

    public static Id createPaymentReference(String donorString, String paymentWrapperString, String campaignId, Id donorId){
        Payment_Reference__c paymentReference = new Payment_Reference__c();
        paymentReference.JSON_Account__c = donorString;
        paymentReference.JSON_Payment_Wrapper__c = paymentWrapperString;
        paymentReference.CampaignId__c = campaignId;
        paymentReference.Account__c = donorId;
        insert paymentReference;
        return paymentReference.Id;
    }

    //Check if the donor already exist - otherwise create new one
    private static Account processDonor(Account donor, Contact con, Boolean isPersonAccount){
        List<Account> donors;
        if(!isPersonAccount){
            donors = [SELECT Id, PersonContactId
            FROM Account WHERE CRMforNonProfit__ICO__c = :donor.CRMforNonProfit__ICO__c ORDER BY CreatedDate ASC LIMIT 1];
            if(!donors.isEmpty()) {
                donor.Id = donors[0].Id;
            }
            donor.npc_bridge__PrimaryContact__c = handleBusinessAccountContact(con, donor.Id);

        } else {
            donors = [SELECT Id, PersonContactId
            FROM Account WHERE PersonEmail = :donor.PersonEmail AND PersonEmail != NULL  ORDER BY CreatedDate ASC LIMIT 1];
            if(!donors.isEmpty()) {
                donor.Id = donors[0].Id;
            }
        }

        if(donor.Id == null){
            if(isPersonAccount){
                donor.PersonLeadSource = 'Donation Page';
                donor.RecordTypeId = ComgateUtil.getPersonAccountRecordTypeId;
            }
            Database.insert(donor, getDmlOptions());
            System.debug(donor);
        } else {
            donor = stripNullValues(donor);
            Database.update(donor, getDmlOptions());
        }

        if(!isPersonAccount && con.AccountId == null) {
            con.AccountId = donor.Id;
            update con;
        }

        return donor;
    }

    private static Database.DMLOptions getDmlOptions(){
        Database.DMLOptions dmlOptions = new Database.DMLOptions();
        dmlOptions.duplicateRuleHeader.allowSave = true;
        return dmlOptions;
    }

    private static Id handleBusinessAccountContact(Contact con, Id existingAccountId){
        List<Contact> contacts = [SELECT Id, AccountId
        FROM Contact WHERE Email = :con.Email AND Email != NULL AND (AccountId = :existingAccountId AND AccountId != NULL) ORDER BY CreatedDate ASC LIMIT 1];
        if(!contacts.isEmpty()) {
            con.Id = contacts[0].Id;
            con.AccountId = contacts[0].AccountId;
        }

        if(con.Id == null){
            con.LeadSource = 'Donation Page';
            Database.insert(con, getDmlOptions());
        } else {
            con = stripNullValues(con);
            Database.update(con, getDmlOptions());
        }

        return con.Id;
    }

    private static Account stripNullValues(Account donor){
        Map<String, Object> originalObjMap = new Map<String, Object>(donor.getPopulatedFieldsAsMap());
        for(String key : originalObjMap.keySet()){
            if(originalObjMap.get(key) == null || originalObjMap.get(key) == '') originalObjMap.remove(key);
        }
        return (Account) JSON.deserialize(JSON.serialize(originalObjMap), Account.class);
    }

    private static Contact stripNullValues(Contact donor){
        Map<String, Object> originalObjMap = new Map<String, Object>(donor.getPopulatedFieldsAsMap());
        for(String key : originalObjMap.keySet()){
            if(originalObjMap.get(key) == null || originalObjMap.get(key) == '') originalObjMap.remove(key);
        }
        return (Contact) JSON.deserialize(JSON.serialize(originalObjMap), Contact.class);
    }

    private static Id prepareDonationRecord(Account donor, DonationPagePaymentWrapper paymentWrapper, String campaignId,
            Bank_Account__c bankAccount){
        campaignId = campaignId != null && campaignId instanceof Id ? campaignId : null; //Check if campaignId is valid
        if(paymentWrapper.donationType != 'oneoff'){
            String chargingDay = getChargingDay();
            Date transactionDate;
            if(ComgateUtil.comgateSettings.Day_Of_Charging__c > 0){
                transactionDate = Date.today().day() >= Integer.valueOf(chargingDay)
                        ? Date.today().addMonths(1).toStartOfMonth().addDays(Integer.valueOf(chargingDay)-1)
                        : Date.today().toStartOfMonth().addDays(Integer.valueOf(chargingDay)-1);
            } else {
                transactionDate = Date.today().toStartOfMonth().addDays(Integer.valueOf(chargingDay)-1);
            }

            GiftCommitment giftCommitment = new GiftCommitment();
            giftCommitment.Name = 'Příslib Daru - ' + (donor?.Name ?? (donor.FirstName + ' ' + donor.LastName)) +
                    ' - ' + paymentWrapper.donationValue.setScale(0) + ' ' + paymentWrapper.currencyIsoCode +
                    ' - ' + Datetime.newInstance(transactionDate, Time.newInstance(0,0,0,0)).format('dd.MM.YYYY');
            giftCommitment.Payment_Method__c = getPaymentMethod(paymentWrapper.paymentOption);
            giftCommitment.DonorId = donor.Id;
            giftCommitment.EffectiveStartDate = Date.today();
            giftCommitment.Comgate_Recurring__c = true;
            giftCommitment.CampaignId = campaignId;
            giftCommitment.Status = 'Active';
            giftCommitment.ScheduleType  = 'Recurring';
            insert giftCommitment;

            insert new GiftDefaultDesignation(
                    ParentRecordId = giftCommitment.Id,
                    GiftDesignationId = getDefaultDesignation().Id,
                    AllocatedPercentage = 100
            );

            GiftCommitmentSchedule giftCommitmentSchedule = new GiftCommitmentSchedule(
                    GiftCommitmentId = giftCommitment.Id,
                    StartDate = transactionDate,
                    TransactionPeriod = paymentWrapper.donationType == 'recurring_yearly' ? 'Yearly' : 'Monthly',
                    TransactionAmount = paymentWrapper.donationValue,
                    TransactionDay = chargingDay,
                    TransactionInterval = 1,
                    PaymentMethod = 'Unknown',
                    Type = 'CreateTransactions',
                    CampaignId = campaignId
            );
            insert giftCommitmentSchedule;

            insert new GiftTransaction(
                    GiftCommitmentId = giftCommitment.Id,
                    GiftCommitmentScheduleId = giftCommitmentSchedule.Id,
                    CampaignId = campaignId,
                    OriginalAmount = paymentWrapper.donationValue,
                    DonorId = donor.Id,
                    GiftType = 'Individual',
                    Name = 'Pravidelný Dar - ' + (donor?.Name ?? (donor.FirstName + ' ' + donor.LastName)) + ' - ' + paymentWrapper.donationValue.setScale(0) + ' ' + paymentWrapper.currencyIsoCode +  ' - ' + Datetime.newInstance(transactionDate, Time.newInstance(0,0,0,0)).format('dd.MM.YYYY'),
                    PaymentMethod = getNpcPaymentMethod(paymentWrapper.paymentOption),
                    Payment_Method__c = getPaymentMethod(paymentWrapper.paymentOption),
                    Status = ComgateUtil.GIFT_TRANSACTION_UNPAID,
                    TransactionDueDate = transactionDate,
                    npc_bridge__Target_Account_Number__c = bankAccount?.Bank_Account_Number__c

            );

            return giftCommitment.Id;
        } else {
            GiftTransaction giftTransaction = new GiftTransaction();
            giftTransaction.Name = 'Jednorázový Dar - ' + (donor?.Name ?? (donor.FirstName + ' ' + donor.LastName)) + ' - ' + paymentWrapper.donationValue.setScale(0) + ' ' + paymentWrapper.currencyIsoCode +  ' - ' + Datetime.now().format('dd.MM.YYYY');
            giftTransaction.DonorId = donor.Id;
            giftTransaction.Payment_Method__c = getPaymentMethod(paymentWrapper.paymentOption);
            giftTransaction.PaymentMethod = getNpcPaymentMethod(paymentWrapper.paymentOption);
            giftTransaction.Status = ComgateUtil.GIFT_TRANSACTION_UNPAID;
            giftTransaction.GiftType = 'Individual';
            giftTransaction.CampaignId = campaignId;
            giftTransaction.OriginalAmount = paymentWrapper.donationValue;
            giftTransaction.TransactionDueDate = Date.today();
            giftTransaction.ProcessorReference = 'Comgate';
            giftTransaction.npc_bridge__Target_Account_Number__c = bankAccount?.Bank_Account_Number__c;
            insert giftTransaction;
            return giftTransaction.Id;
        }
    }

    private static String getChargingDay(){
        if (ComgateUtil.comgateSettings.Day_Of_Charging__c == null) return getTransactionDay();
        if (ComgateUtil.comgateSettings.Day_Of_Charging__c == 0) return getTransactionDay();
        return Integer.valueOf(ComgateUtil.comgateSettings.Day_Of_Charging__c).toString();
    }

    private static GiftDesignation getDefaultDesignation(){
        List<GiftDesignation> designation = [SELECT Id FROM GiftDesignation WHERE IsActive = TRUE AND IsDefault = TRUE];
        GiftDesignation defaultDesignation;
        if(designation.size() == 0){
            defaultDesignation = new GiftDesignation(Name = 'Default', IsActive = TRUE, IsDefault = TRUE);
            insert defaultDesignation;
        } else {
            defaultDesignation = designation[0];
        }
        return defaultDesignation;
    }

    private static String getTransactionDay(){
        if(Date.today().day() > 30) return 'LastDay';
        return Date.today().day().toString();
    }


    public static String getPaymentMethod(String paymentOption){
        switch on paymentOption{
            when 'banktransfer','bankTransfer'{
                return 'Bank Transfer';
            }
            when 'card'{
                return 'CreditCard';
            }
            when 'paypal'{
                return 'PayPal';
            }
            when 'sepa'{
                return 'SEPA Direct Debit';
            }
        }
        return null;
    }


    public static String getNpcPaymentMethod(String paymentOption){
        switch on paymentOption{
            when 'banktransfer','bankTransfer'{
                return 'Bankovní převod';
            }
            when 'card'{
                return 'Credit Card';
            }
            when 'paypal'{
                return 'PayPal';
            }
        }
        return null;
    }
}
