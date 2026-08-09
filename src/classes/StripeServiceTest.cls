@IsTest
public with sharing class StripeServiceTest {

    @TestSetup
    public static void testSetup(){
        Account donor = StripeTestFactory.getDonor();
        insert donor;
        
        GiftTransaction giftTransaction = StripeTestFactory.getGiftTransaction(donor.Id, StripeUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;
    }
    
    @IsTest
    public static void test_capturePaymentIntent(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.CapturePaymentIntent());
        GiftTransaction giftTransaction = [SELECT Id, OriginalAmount FROM GiftTransaction LIMIT 1];
        
        Test.startTest();
        StripePaymentIntentCaptureResponse response = StripeService.capturePaymentIntent('TEST', giftTransaction.OriginalAmount, StripeUtil.DEFAULT_CURRENCY, giftTransaction.Id);
        Test.stopTest();
        
        Assert.areEqual('succeeded', response.status);
        Assert.areEqual(1000, response.amount_received);
        Assert.areEqual(1000, response.amount);
    }
}