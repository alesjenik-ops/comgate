@IsTest
public with sharing class ComgateWebhookTest {

    @TestSetup
    public static void testSetup(){
        ComgateTestFactory.createComgateSettings();
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
    }

    private static void callWebhook(String body){
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/comgatewebhook';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(body);
        RestContext.request = req;
        RestContext.response = new RestResponse();
        ComgateWebhook.doPost();
    }

    @IsTest
    public static void test_paidOneOff_viaPaymentReference(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, null);
        paymentReference.Gift_Transaction__c = giftTransaction.Id;
        insert paymentReference;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(paymentReference.Id, 'PAID', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Payment_Method__c, Comgate_Transaction_Id__c,
                Attempt_Counter__c, TransactionDate FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.areEqual('PAID', giftTransactionAssert.Status__c);
        Assert.areEqual('Credit Card', giftTransactionAssert.Payment_Method__c);
        Assert.areEqual(ComgateMockTest.TRANS_ID, giftTransactionAssert.Comgate_Transaction_Id__c);
        Assert.areEqual(1, giftTransactionAssert.Attempt_Counter__c);
        Assert.areEqual(Date.today(), giftTransactionAssert.TransactionDate);

        Payment_Log__c log = [SELECT Id, Status__c, Gift_Transaction__c, Payment_Reference__c, Transaction_Id__c FROM Payment_Log__c];
        Assert.areEqual('PAID', log.Status__c);
        Assert.areEqual(giftTransaction.Id, log.Gift_Transaction__c);
        Assert.areEqual(paymentReference.Id, log.Payment_Reference__c);

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @IsTest
    public static void test_paidRecurring_viaGiftCommitment(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        giftCommitment.Comgate_Authorized__c = false;
        insert giftCommitment;

        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftCommitment.Id, 'PAID', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Comgate_Authorized__c, Comgate_Initial_Transaction_Id__c,
                Payment_Method__c FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.isTrue(giftCommitmentAssert.Comgate_Authorized__c);
        Assert.areEqual(ComgateMockTest.TRANS_ID, giftCommitmentAssert.Comgate_Initial_Transaction_Id__c);
        Assert.areEqual('Credit Card', giftCommitmentAssert.Payment_Method__c);

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.areEqual('PAID', giftTransactionAssert.Status__c);
    }

    @IsTest
    public static void test_paidRecurring_noUnpaidTransaction(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        giftCommitment.Comgate_Authorized__c = false;
        insert giftCommitment;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftCommitment.Id, 'PAID', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Comgate_Authorized__c FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.isTrue(giftCommitmentAssert.Comgate_Authorized__c);
        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @IsTest
    public static void test_cancelledOneOff(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('CANCELLED'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftTransaction.Id, 'CANCELLED', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Attempt_Counter__c, Status_Reason__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_FAILED, giftTransactionAssert.Status);
        Assert.areEqual('CANCELLED', giftTransactionAssert.Status__c);
        Assert.areEqual(1, giftTransactionAssert.Attempt_Counter__c);
        Assert.areEqual('payer cancelled', giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_cancelledPaidTransaction_untouched(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_PAID);
        giftTransaction.TransactionDate = Date.today();
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('CANCELLED'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftTransaction.Id, 'CANCELLED', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.isNull(giftTransactionAssert.Status__c);
    }

    @IsTest
    public static void test_cancelledRecurring(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('CANCELLED'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftCommitment.Id, 'CANCELLED', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Status FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual('CANCELLED', giftTransactionAssert.Status__c);
    }

    @IsTest
    public static void test_authorizedRecurring(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftCommitment giftCommitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        giftCommitment.Comgate_Authorized__c = false;
        insert giftCommitment;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('AUTHORIZED'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftCommitment.Id, 'AUTHORIZED', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftCommitment giftCommitmentAssert = [SELECT Id, Comgate_Authorized__c, Comgate_Initial_Transaction_Id__c
                FROM GiftCommitment WHERE Id = :giftCommitment.Id];
        Assert.isTrue(giftCommitmentAssert.Comgate_Authorized__c);
        Assert.areEqual(ComgateMockTest.TRANS_ID, giftCommitmentAssert.Comgate_Initial_Transaction_Id__c);
    }

    @IsTest
    public static void test_paidOneOff_googlePay(){
        //Regression: Comgate sends method=GOOGLEPAY (not GPAY). While the code was unmapped the upsert
        //failed with INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST and the webhook answered 500.
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        Payment_Reference__c paymentReference = ComgateTestFactory.getPaymentReference(donor.Id, null);
        paymentReference.Gift_Transaction__c = giftTransaction.Id;
        insert paymentReference;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(paymentReference.Id, 'PAID', 'GOOGLEPAY', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c, Payment_Method__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.areEqual('PAID', giftTransactionAssert.Status__c);
        Assert.areEqual('Google Pay', giftTransactionAssert.Payment_Method__c);

        Payment_Log__c log = [SELECT Id, Payment_Method__c FROM Payment_Log__c];
        Assert.areEqual('GOOGLEPAY', log.Payment_Method__c);

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @IsTest
    public static void test_paidOneOff_unknownPaymentMethod(){
        //An unknown method must not reach the restricted picklist - the payment still has to be
        //recorded and the raw code stays on Payment_Log__c.
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftTransaction.Id, 'PAID', 'LATER_TWISTO', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Payment_Method__c
                FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.isNull(giftTransactionAssert.Payment_Method__c);

        Payment_Log__c log = [SELECT Id, Payment_Method__c FROM Payment_Log__c];
        Assert.areEqual('LATER_TWISTO', log.Payment_Method__c);

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @IsTest
    public static void test_statusMismatch_noChanges(){
        Account donor = [SELECT Id FROM Account LIMIT 1];
        GiftTransaction giftTransaction = ComgateTestFactory.getGiftTransaction(donor.Id, ComgateUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('CANCELLED'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson(giftTransaction.Id, 'PAID', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status__c FROM GiftTransaction WHERE Id = :giftTransaction.Id];
        Assert.areEqual(ComgateUtil.GIFT_TRANSACTION_UNPAID, giftTransactionAssert.Status);
        Assert.isNull(giftTransactionAssert.Status__c);
        Assert.areEqual(0, [SELECT COUNT() FROM Payment_Log__c]);
        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @IsTest
    public static void test_nonIdRefId_logOnly(){
        Test.setMock(HttpCalloutMock.class, new ComgateMockTest.PaymentStatusResponse('PAID'));

        Test.startTest();
        callWebhook(ComgateTestFactory.getWebhookEventJson('external-ref-123', 'PAID', 'CARD_CZ_COMGATE', ComgateMockTest.TRANS_ID));
        Test.stopTest();

        Payment_Log__c log = [SELECT Id, Status__c, Gift_Transaction__c, Gift_Commitment__c, Payment_Reference__c FROM Payment_Log__c];
        Assert.areEqual('PAID', log.Status__c);
        Assert.isNull(log.Gift_Transaction__c);
        Assert.isNull(log.Gift_Commitment__c);
        Assert.isNull(log.Payment_Reference__c);
        Assert.areEqual(200, RestContext.response.statusCode);
    }
}
