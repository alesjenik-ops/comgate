@IsTest
public with sharing class StripeNotificationPlatformEventHndlTest {

    @TestSetup
    public static void testSetup(){
        StripeTestFactory.createStripeSettings();

        Account donor = StripeTestFactory.getDonor();
        donor.Stripe_Customer_Id__c = null;
        insert donor;

        GiftCommitment giftCommitment = StripeTestFactory.getGiftCommitment(donor.Id);
        insert giftCommitment;

        GiftCommitmentSchedule giftCommitmentSchedule = StripeTestFactory.getGiftCommitmentSchedule(giftCommitment.Id);
        insert giftCommitmentSchedule;

        GiftTransaction giftTransaction = StripeTestFactory.getGiftTransaction(donor.Id, StripeUtil.GIFT_TRANSACTION_UNPAID);
        insert giftTransaction;

        GiftTransaction giftTransaction2 = StripeTestFactory.getGiftTransaction(donor.Id, StripeUtil.GIFT_TRANSACTION_UNPAID);
        giftTransaction2.GiftCommitmentId = giftCommitment.Id;
        insert giftTransaction2;

        Payment_Reference__c paymentReference = StripeTestFactory.getPaymentReference(donor.Id, null);
        paymentReference.Gift_Commitment__c = giftCommitment.Id;
        insert paymentReference;

        Payment_Log__c sessionLog = StripeTestFactory.getRecurringPaymentLog(giftCommitment.Id);
        sessionLog.Payment_Reference__c = paymentReference.Id;
        insert sessionLog;
    }
    
    @IsTest
    public static void test_checkoutSessionExpired_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'checkout.session.expired'
        );
        
        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        GiftCommitment giftCommitmentAssert = [SELECT Id, Status, Description FROM GiftCommitment];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);
        Assert.areEqual('Session Expired', giftCommitmentAssert.Description);
    }
    
    @IsTest
    public static void test_checkoutSessionExpired_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'checkout.session.expired'
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId, 
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        
        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransactionId];
        Assert.areEqual(StripeUtil.GIFT_TRANSACTION_FAILED, giftTransactionAssert.Status);
        Assert.areEqual('Session Expired', giftTransactionAssert.Status_Reason__c);
    }
    
    @IsTest
    public static void test_chargeExpired_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.expired'
        );
        
        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        GiftCommitment giftCommitmentAssert = [SELECT Id, Status, Description FROM GiftCommitment];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);
        Assert.areEqual('Charge Expired', giftCommitmentAssert.Description);
    }
    
    @IsTest
    public static void test_chargeExpired_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.expired'
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId, 
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        
        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransactionId];
        Assert.areEqual(StripeUtil.GIFT_TRANSACTION_FAILED, giftTransactionAssert.Status);
        Assert.areEqual('Charge Expired', giftTransactionAssert.Status_Reason__c);
    }
    
    @IsTest
    public static void test_refunded_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.refunded'
        );
        
        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        GiftCommitment giftCommitmentAssert = [SELECT Id, Status, Description FROM GiftCommitment];
        Assert.areEqual('Closed', giftCommitmentAssert.Status);
        Assert.areEqual('Refunded', giftCommitmentAssert.Description);
    }
    
    @IsTest
    public static void test_refunded_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.refunded'
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId,
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status_Reason__c FROM GiftTransaction WHERE Id =: giftTransactionId];
        Assert.areEqual(StripeUtil.GIFT_TRANSACTION_FAILED, giftTransactionAssert.Status);
        Assert.areEqual('Refunded', giftTransactionAssert.Status_Reason__c);
    }
    
    @IsTest
    public static void test_chargeFailed_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.failed',
                Payment_Intent__c = StripeMockTest.PAYMENT_INTENT_ID
        );
        
        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status, Status_Reason__c, Status__c, Attempt_Counter__c, Stripe_Payment_Intent__c
            FROM GiftTransaction WHERE
            GiftCommitmentId != NULL ORDER BY TransactionDueDate ASC LIMIT 1];
        Assert.areEqual(notification.Reason__c, giftTransactionAssert.Status_Reason__c);
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(1, giftTransactionAssert.Attempt_Counter__c);
        Assert.areEqual(notification.Payment_Intent__c, giftTransactionAssert.Stripe_Payment_Intent__c);
    }
    
    @IsTest
    public static void test_chargeFailed_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.failed',
                Payment_Intent__c = StripeMockTest.PAYMENT_INTENT_ID,
                Reason__c = 'CHARGE FAILED'
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId,
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        
        GiftTransaction giftTransactionAssert = [SELECT Id, Attempt_Counter__c, Status_Reason__c, Status__c,
                Stripe_Payment_Intent__c FROM GiftTransaction WHERE Id =: giftTransactionId];
        Assert.areEqual(notification.Reason__c, giftTransactionAssert.Status_Reason__c);
        Assert.areEqual('ERROR', giftTransactionAssert.Status__c);
        Assert.areEqual(1, giftTransactionAssert.Attempt_Counter__c);
        Assert.areEqual(notification.Payment_Intent__c, giftTransactionAssert.Stripe_Payment_Intent__c);
    }


    @IsTest
    public static void test_chargeSucceeded_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.succeeded',
                Amount_Captured__c = 200,
                Payment_Method__c = 'CreditCard'
        );

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();
        
        GiftTransaction giftTransactionAssert = [SELECT Id, Status_Reason__c, Status__c, Payment_Method__c,
                Stripe_Payment_Intent__c, Status FROM GiftTransaction WHERE GiftCommitmentId != NULL ORDER BY TransactionDueDate ASC LIMIT 1];
        Assert.areEqual(null, giftTransactionAssert.Status_Reason__c);
        Assert.areEqual('CAPTURED', giftTransactionAssert.Status__c);
        Assert.areEqual('CreditCard', giftTransactionAssert.Payment_Method__c);
        Assert.areEqual(StripeUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.areEqual(notification.Payment_Intent__c, giftTransactionAssert.Stripe_Payment_Intent__c);
    }

    @IsTest
    public static void test_chargeCapture_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'charge.captured',
                Amount_Captured__c = 200,
                Payment_Method__c = 'CreditCard'
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId,
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();

        GiftTransaction giftTransactionAssert = [SELECT Id, Status_Reason__c, Status__c, Payment_Method__c,
                Stripe_Payment_Intent__c, Status FROM GiftTransaction WHERE Id =: giftTransactionId];
        Assert.areEqual(null, giftTransactionAssert.Status_Reason__c);
        Assert.areEqual('CAPTURED', giftTransactionAssert.Status__c);
        Assert.areEqual('CreditCard', giftTransactionAssert.Payment_Method__c);
        Assert.areEqual(StripeUtil.GIFT_TRANSACTION_PAID, giftTransactionAssert.Status);
        Assert.areEqual(notification.Payment_Intent__c, giftTransactionAssert.Stripe_Payment_Intent__c);
    }

    @IsTest
    public static void test_checkoutSessionCompleted_opp(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Id giftTransactionId = [SELECT Id FROM GiftTransaction WHERE GiftCommitmentId = NULL LIMIT 1].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'checkout.session.completed',
                Payment_Method__c = 'CreditCard',
                Stripe_Customer_Id__c = StripeMockTest.CUSTOMER_ID
        );
        update new Payment_Reference__c(
                Id = paymentReferenceId,
                Gift_Transaction__c = giftTransactionId,
                Gift_Commitment__c = null);

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();

        Account donorAssert = [SELECT Id, Stripe_Customer_Id__c FROM Account LIMIT 1];
        Assert.areEqual(notification.Stripe_Customer_Id__c, donorAssert.Stripe_Customer_Id__c);
    }

    @IsTest
    public static void test_checkoutSessionCompleted_rec(){
        Id paymentReferenceId = [SELECT Id FROM Payment_Reference__c].Id;
        Stripe_Notification__e notification = new Stripe_Notification__e(
                Payment_Reference_Id__c = paymentReferenceId,
                Type__c = 'checkout.session.completed',
                Payment_Method__c = 'CreditCard',
                Stripe_Customer_Id__c = StripeMockTest.CUSTOMER_ID
        );

        Test.startTest();
        EventBus.publish(new List<SObject>{notification});
        Test.stopTest();

        Account donorAssert = [SELECT Id, Stripe_Customer_Id__c FROM Account LIMIT 1];
        GiftCommitment giftCommitmentAssert = [SELECT Id, Stripe_Authorized__c, Payment_Method__c FROM GiftCommitment LIMIT 1];
        Assert.areEqual(true, giftCommitmentAssert.Stripe_Authorized__c);
        Assert.areEqual(notification.Payment_Method__c, giftCommitmentAssert.Payment_Method__c);
        Assert.areEqual(notification.Stripe_Customer_Id__c, donorAssert.Stripe_Customer_Id__c);
    }
}