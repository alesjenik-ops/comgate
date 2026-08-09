@IsTest
public with sharing class StripePaymentFormControllerTest {

    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();
    }

    @IsTest
    public static void test_getStripePublicKey(){

        Test.startTest();
        String stripePublicKey = StripePaymentFormController.getStripePublicKey();
        Test.stopTest();
        
        Assert.areEqual(StripeUtil.stripeSettings.Public_Key__c, stripePublicKey);
    }
}