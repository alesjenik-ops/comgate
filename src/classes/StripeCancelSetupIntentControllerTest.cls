@IsTest
public with sharing class StripeCancelSetupIntentControllerTest {

    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Account donor = StripeTestFactory.getDonor();
        insert donor;

        GiftCommitment giftCommitment = StripeTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        GiftCommitmentSchedule giftCommitmentSchedule = StripeTestFactory.getGiftCommitmentSchedule(giftCommitment.Id);
        insert giftCommitmentSchedule;
        
        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, null);
        paymentReference.Gift_Commitment__c = giftCommitment.Id;
        insert paymentReference;
        
        Payment_Log__c sessionLog = StripeTestFactory.createSessionCompletedLog();
        sessionLog.Payment_Reference__c = paymentReference.Id;
        sessionLog.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        insert sessionLog;
    }
    
    @IsTest
    public static void test_cancelSetupIntent(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.CancelSetupIntent());
        GiftCommitment giftCommitment = [SELECT Id FROM GiftCommitment LIMIT 1];
        
        Test.startTest();
        StripeCancelSetupIntentController.cancelSetupIntent('requested_by_customer', giftCommitment.Id);
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Status, Description
            FROM GiftCommitment WHERE Id =: giftCommitment.Id];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);
        Assert.areEqual('requested_by_customer', giftCommitmentAssert.Description);
    }
    
}