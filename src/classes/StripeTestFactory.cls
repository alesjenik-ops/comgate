public with sharing class StripeTestFactory {

    public static Contact getContact(){
        return new Contact(FirstName = 'Karel', LastName = 'Vomacka', 
                Email = 'karel.vomacka@test.test' + Math.random());
    }

    public static Account getDonor(){
        return new Account(FirstName = 'Karel', LastName = 'Vomacka',
                PersonEmail = 'karel.vomacka@test.test' + Math.random(),
                RecordTypeId = StripeUtil.getPersonAccountRecordTypeId,
                Stripe_Customer_Id__c = StripeMockTest.CUSTOMER_ID);
    }

    public static Opportunity getOpportunity(Id contactId, String stageName){
        Opportunity opp = new Opportunity();
        opp.Name = 'Test Opp';
        opp.ContactId = contactId;
        opp.CloseDate = Date.today().addDays(5);
        opp.Amount = 200;
        opp.StageName = stageName;
        return opp;
    }

    public static GiftTransaction getGiftTransaction(Id donorId, String status){
        return new GiftTransaction(
                Name = 'Test Opp',
                Status =status,
                DonorId = donorId,
                TransactionDueDate = System.today ().addDays(30),
                OriginalAmount = 200.00,
                PaymentMethod = 'Unknown'
        );
    }

    public static void createStripeSettings(){
        Stripe_Settings__c stripeSettings = new Stripe_Settings__c();
        stripeSettings.Attempt_Limit__c = 3;
        stripeSettings.Attempt_Delay__c = 7;
        stripeSettings.Public_Key__c = 'APIKEY';
        stripeSettings.Day_Of_Charging__c = Date.today().day();
        stripeSettings.HMAC_Signature__c = 'whsec_r5pqAW0VbVNcs9MY2tGuo4XuafPDvuaT';
        insert stripeSettings;
    }
    
    public static Payment_Log__c createSessionCompletedLog(){
        Payment_Log__c log = new Payment_Log__c();
        log.Event_Code__c = 'checkout.session.completed';
        return log;
    }

    public static Payment_Log__c getRecurringPaymentLog(Id giftCommitmentId){
        Payment_Log__c log = createSessionCompletedLog();
        log.Gift_Commitment__c = giftCommitmentId;
        log.Payment_Method__c = 'paypal';
        log.Amount__c = 20;
        log.Currency__c = 'EUR';
        return log;
    }

    public static GiftCommitment getGiftCommitment(Id donorId){
        return new GiftCommitment(
                Name = 'Test RD 1',
                DonorId = donorId,
                Status = 'Active',
                EffectiveStartDate = Date.today(),
                Stripe_Authorized__c = true,
                Stripe_Recurring__c = true
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
        paymentWrapper.allowedPaymentMethods = new String[]{'card','paypal','sepadirectdebit'};
        return paymentWrapper;
    }

    public static Campaign getCampaign(){
        Campaign cam = new Campaign();
        cam.Name = 'Test Campaign';
        cam.StartDate = Date.today();
        cam.IsActive = true;
        return cam;
    }
}