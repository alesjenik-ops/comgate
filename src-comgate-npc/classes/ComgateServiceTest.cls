@IsTest
public with sharing class ComgateServiceTest {

    @IsTest
    public static void test_getPayment_created(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentCreatedResponse());

        Test.startTest();
        ComgatePaymentResponseWrapper responseWrapper = ComgateService.getPayment(new ComgatePaymentRequestWrapper());
        Test.stopTest();

        Assert.areEqual(ComgateMockTest.TRANS_ID, responseWrapper.transId);
        Assert.areEqual(ComgateMockTest.REDIRECT_URL, responseWrapper.redirect);
    }

    @IsTest
    public static void test_getPayment_error(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ErrorResponse());

        Test.startTest();
        try{
            ComgateService.getPayment(new ComgatePaymentRequestWrapper());
            Assert.fail('Exception expected');
        } catch (Exception e){
            Assert.isTrue(e.getMessage().contains(String.valueOf(ComgateMockTest.ERROR_CODE)));
        }
        Test.stopTest();
    }

    @IsTest
    public static void test_getPayment_serverError(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ServerErrorResponse());

        Test.startTest();
        ComgatePaymentResponseWrapper responseWrapper = ComgateService.getPayment(new ComgatePaymentRequestWrapper());
        Test.stopTest();

        Assert.isNull(responseWrapper);
    }

    @IsTest
    public static void test_getRecurringPayment_created(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.RecurringCreatedResponse());

        Test.startTest();
        ComgatePaymentResponseWrapper responseWrapper = ComgateService.getRecurringPayment(new ComgateRecurringRequestWrapper());
        Test.stopTest();

        Assert.areEqual(ComgateMockTest.TRANS_ID, responseWrapper.transId);
        Assert.isNull(responseWrapper.code);
    }

    @IsTest
    public static void test_getRecurringPayment_error(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ErrorResponse());

        Test.startTest();
        ComgatePaymentResponseWrapper responseWrapper = ComgateService.getRecurringPayment(new ComgateRecurringRequestWrapper());
        Test.stopTest();

        Assert.areEqual(ComgateMockTest.ERROR_CODE, responseWrapper.code);
        Assert.areEqual(ComgateMockTest.ERROR_MESSAGE, responseWrapper.message);
    }

    @IsTest
    public static void test_getPaymentStatus(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        ComgatePaymentStatusResponseWrapper responseWrapper = ComgateService.getPaymentStatus(ComgateMockTest.TRANS_ID);
        Test.stopTest();

        Assert.areEqual('PAID', responseWrapper.status);
        Assert.areEqual(ComgateMockTest.TRANS_ID, responseWrapper.transId);
    }

    @IsTest
    public static void test_getPaymentStatus_serverError(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.ServerErrorResponse());

        Test.startTest();
        ComgatePaymentStatusResponseWrapper responseWrapper = ComgateService.getPaymentStatus(ComgateMockTest.TRANS_ID);
        Test.stopTest();

        Assert.isNull(responseWrapper);
    }
}
