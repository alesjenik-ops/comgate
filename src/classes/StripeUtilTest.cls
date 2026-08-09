@IsTest
public with sharing class StripeUtilTest {

    @IsTest
    public static void test_convertStripePaymentMethod(){
        Test.startTest();
        Assert.areEqual('CreditCard', StripeUtil.convertStripePaymentMethod('card'));
        Assert.areEqual('PayPal', StripeUtil.convertStripePaymentMethod('paypal'));
        Assert.areEqual('SEPA Direct Debit', StripeUtil.convertStripePaymentMethod('sepa'));
        Assert.areEqual('SEPA Direct Debit', StripeUtil.convertStripePaymentMethod('sepa_debit'));
        Test.stopTest();
    }
    
    @IsTest
    public static void test_currencyMultiplier(){
        Test.startTest();
        Assert.areEqual(1, StripeUtil.currencyMultiplier('JPY'));
        Assert.areEqual(100, StripeUtil.currencyMultiplier('EUR'));
        Assert.areEqual(1000, StripeUtil.currencyMultiplier('BHD'));
        Test.stopTest();
    }
    
    @IsTest
    public static void test_getDateFromUTCStamp_exception(){
        Test.startTest();
        Assert.areEqual('', StripeUtil.getDateFromUTCStamp(null));
        Test.stopTest();
    }
}