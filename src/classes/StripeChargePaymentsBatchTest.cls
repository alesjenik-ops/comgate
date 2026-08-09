@IsTest
public with sharing class StripeChargePaymentsBatchTest {
    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Account donor = StripeTestFactory.getDonor();
        insert donor;

        GiftCommitment giftCommitment = StripeTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        GiftCommitmentSchedule giftCommitmentSchedule = StripeTestFactory.getGiftCommitmentSchedule(giftCommitment.Id);
        insert giftCommitmentSchedule;

        GiftTransaction giftTransaction = StripeTestFactory.getGiftTransaction(donor.Id, StripeUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction.GiftCommitmentId = giftCommitment.Id;
        insert giftTransaction;

        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, null);
        paymentReference.Gift_Commitment__c = giftCommitment.Id;
        insert paymentReference;

        Payment_Log__c sessionLog = StripeTestFactory.getRecurringPaymentLog(giftCommitment.Id);
        sessionLog.Payment_Reference__c = paymentReference.Id;
        insert sessionLog;
    }

    @IsTest
    public static void test_missingSessionAuthorization(){
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }
        delete [SELECT Id FROM Payment_Log__c];

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();
        
        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeChargePaymentsBatch.ERROR_MISSING_SESSION_AUTHORIZATION, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_missingSetupIntent(){
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeChargePaymentsBatch.ERROR_MISSING_SETUP_INTENT, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_getSetupIntent_error(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.ErrorResponse());
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        update log;

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeMockTest.ERROR_MESSAGE, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_getPaymentMethod_error(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.ErrorResponse());
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        log.Payment_Method_Id__c = StripeMockTest.PAYMENT_METHOD_ID;
        update log;

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeMockTest.ERROR_MESSAGE, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_cratePaymentIntent_error(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.ErrorResponse());
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        log.Payment_Method_Id__c = StripeMockTest.PAYMENT_METHOD_ID;
        update log;

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeMockTest.ERROR_MESSAGE, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_capturePaymentIntent_error(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.ErrorResponse());
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            giftTransaction.Stripe_Payment_Intent__c = StripeMockTest.PAYMENT_INTENT_ID;
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        log.Payment_Method_Id__c = StripeMockTest.PAYMENT_METHOD_ID;
        update log;
        
        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status__c, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(StripeMockTest.ERROR_MESSAGE, giftTransactionAssert.Status_Reason__c);
    }

    @IsTest
    public static void test_setupIntentToCapture_fullProcess(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.PaymentIntentFull());

        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        update log;

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();

        Payment_Log__c logAssert = [SELECT Id, Payment_Method_Id__c, Setup_Intent__c 
            FROM Payment_Log__c WHERE Id = :log.Id];
        Assert.areEqual(StripeMockTest.SETUP_INTENT_ID, logAssert.Setup_Intent__c);
        Assert.areEqual(StripeMockTest.PAYMENT_METHOD_ID, logAssert.Payment_Method_Id__c);

        GiftTransaction giftTransactionAssert = [SELECT Id, Stripe_Payment_Intent__c, Status, Status__c
            FROM GiftTransaction WHERE Id =: giftTransaction.Id];
        Assert.areEqual(StripeMockTest.PAYMENT_INTENT_ID, giftTransactionAssert.Stripe_Payment_Intent__c);
    }
    
    @IsTest
    public static void test_fetchPaymentMethods(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.GetSetupIntent());

        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id, Payment_Reference__c FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        update log;

        Test.startTest();
        StripeChargePaymentsBatch.fetchPaymentsMethodIds(new Set<Id>{log.Payment_Reference__c});
        Test.stopTest();

        Payment_Log__c logAssert = [SELECT Id, Payment_Method_Id__c, Setup_Intent__c 
            FROM Payment_Log__c WHERE Id = :log.Id];
        Assert.areEqual(StripeMockTest.SETUP_INTENT_ID, logAssert.Setup_Intent__c);
        Assert.areEqual(StripeMockTest.PAYMENT_METHOD_ID, logAssert.Payment_Method_Id__c);
    }
    
    @IsTest
    public static void test_fetchPaymentMethods_queueable(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.GetSetupIntent());

        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id, Payment_Reference__c FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        update log;

        Test.startTest();
        System.enqueueJob(new StripeChargePaymentsBatch.FetchPaymentMethodsQueueable(new Set<Id>{log.Payment_Reference__c}));
        Test.stopTest();

        Payment_Log__c logAssert = [SELECT Id, Payment_Method_Id__c, Setup_Intent__c 
            FROM Payment_Log__c WHERE Id = :log.Id];
        Assert.areEqual(StripeMockTest.SETUP_INTENT_ID, logAssert.Setup_Intent__c);
        Assert.areEqual(StripeMockTest.PAYMENT_METHOD_ID, logAssert.Payment_Method_Id__c);
    }

    @IsTest
    public static void test_reCaptureFailedRecurringOpportunity(){
        Test.setMock(HttpCalloutMock.class, new StripeMockTest.CapturePaymentIntent());
        GiftTransaction giftTransaction = [SELECT Id, TransactionDueDate FROM GiftTransaction ORDER BY TransactionDueDate ASC LIMIT 1];
        if(giftTransaction.TransactionDueDate > Date.today()){
            giftTransaction.TransactionDueDate = Date.today();
            giftTransaction.Stripe_Payment_Intent__c = StripeMockTest.PAYMENT_INTENT_ID;
            giftTransaction.Attempt_Counter__c = 2;
            giftTransaction.Status__c = 'ERROR';
            giftTransaction.Last_Attempt_Date__c = Date.today().addDays(-8);
            giftTransaction.Payment_Method__c = 'CreditCard';
            update giftTransaction;
        }

        Payment_Log__c log = [SELECT Id FROM Payment_Log__c LIMIT 1];
        log.Setup_Intent__c = StripeMockTest.SETUP_INTENT_ID;
        log.Payment_Method_Id__c = StripeMockTest.PAYMENT_METHOD_ID;
        update log;
        

        Test.startTest();
        Database.executeBatch(new StripeChargePaymentsBatch());
        Test.stopTest();
    }

    @IsTest
    public static void test_scheduler() {
        Test.startTest();
        String jobId = System.schedule('ScheduledApexTest2',
                '0 0 0 15 3 ? ' + Date.today().addYears(1).year(),
                new StripeChargePaymentsBatch());
        Test.stopTest();

        List<CronTrigger> jobs = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime
                FROM CronTrigger
                WHERE Id = :jobId
        ];

        System.assertEquals(1, jobs.size());
    }

}