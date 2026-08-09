public with sharing class ComgateTestFactory {

    public static Contact getContact(){
        return new Contact(FirstName = 'Karel', LastName = 'Vomacka',
                Email = 'karel.vomacka@test.test' + Math.random());
    }

    public static Account getDonor(){
        return new Account(FirstName = 'Karel', LastName = 'Vomacka',
                PersonEmail = 'karel.vomacka@test.test' + Math.random(),
                RecordTypeId = ComgateUtil.getPersonAccountRecordTypeId);
    }

    public static GiftTransaction getGiftTransaction(Id donorId, String status){
        return new GiftTransaction(
                Name = 'Test Gift',
                Status = status,
                DonorId = donorId,
                TransactionDueDate = System.today().addDays(30),
                OriginalAmount = 200.00,
                PaymentMethod = 'Unknown'
        );
    }

    public static GiftCommitment getGiftCommitment(Id donorId){
        return new GiftCommitment(
                Name = 'Test RD 1',
                DonorId = donorId,
                Status = 'Active',
                EffectiveStartDate = Date.today(),
                Comgate_Authorized__c = true,
                Comgate_Recurring__c = true
        );
    }

    public static GiftCommitmentSchedule getGiftCommitmentSchedule(Id giftCommitmentId){
        return new GiftCommitmentSchedule(
                Type = 'CreateTransactions',
                StartDate = Date.today(),
                TransactionPeriod = 'Monthly',
                TransactionAmount = 100,
                GiftCommitmentId = giftCommitmentId
        );
    }

    public static void createComgateSettings(){
        Comgate_Settings__c comgateSettings = new Comgate_Settings__c();
        comgateSettings.Attempt_Limit__c = 3;
        comgateSettings.Attempt_Delay__c = 7;
        comgateSettings.Day_Of_Charging__c = Date.today().day();
        insert comgateSettings;
    }

    public static Payment_Reference__c getPaymentReference(Id donorId, Id campaignId){
        Payment_Reference__c paymentReference = new Payment_Reference__c();
        paymentReference.CampaignId__c = campaignId;
        paymentReference.Account__c = donorId;
        return paymentReference;
    }

    public static DonationPagePaymentWrapper getPaymentWrapper(String donationType, Decimal donationValue, String paymentOption, String redirectURL){
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();
        paymentWrapper.donationType = donationType;
        paymentWrapper.donationValue = donationValue;
        paymentWrapper.paymentOption = paymentOption;
        paymentWrapper.redirectURL = redirectURL;
        paymentWrapper.currencyIsoCode = 'CZK';
        paymentWrapper.allowedPaymentMethods = new String[]{'card','bankTransfer'};
        return paymentWrapper;
    }

    public static Campaign getCampaign(){
        Campaign cam = new Campaign();
        cam.Name = 'Test Campaign';
        cam.StartDate = Date.today();
        cam.IsActive = true;
        return cam;
    }

    public static String getWebhookEventJson(String refId, String status, String method, String transId){
        return JSON.serialize(new Map<String, Object>{
                'transId' => transId,
                'merchant' => 'merchant.test',
                'test' => 'true',
                'price' => 20000,
                'curr' => 'CZK',
                'label' => 'Dar',
                'refId' => refId,
                'method' => method,
                'status' => status,
                'vs' => '1234567890',
                'paymentErrorReason' => status == 'CANCELLED' ? 'payer cancelled' : null
        });
    }
}
