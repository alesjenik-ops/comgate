@IsTest
private class DKD_PaymentMethodMapperTest {

    private static Account insertDonor() {
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
        return donor;
    }

    private static GiftTransaction newGift(Id donorId) {
        return new GiftTransaction(
                Name = 'Test Gift',
                Status = 'Unpaid',
                DonorId = donorId,
                TransactionDueDate = Date.today(),
                OriginalAmount = 500
        );
    }

    @IsTest
    static void comgateMethodMapsGatewayValues() {
        Assert.areEqual('Comgate - Karta', DKD_PaymentMethodMapper.comgateMethod('CreditCard'));
        Assert.areEqual('Comgate - Karta', DKD_PaymentMethodMapper.comgateMethod('Credit Card'));
        Assert.areEqual('Comgate - Karta', DKD_PaymentMethodMapper.comgateMethod('CARD_CZ_COMGATE'));
        Assert.areEqual('Comgate - Bankovní tlačítko', DKD_PaymentMethodMapper.comgateMethod('Online Bank'));
        Assert.areEqual('Comgate - Bankovní tlačítko', DKD_PaymentMethodMapper.comgateMethod('BANK_CZ_KB'));
        Assert.areEqual('Comgate - Převod', DKD_PaymentMethodMapper.comgateMethod('Bank Transfer'));
        Assert.areEqual('Comgate - Převod', DKD_PaymentMethodMapper.comgateMethod('TRANSFER'));
        Assert.areEqual('Comgate - Google Pay', DKD_PaymentMethodMapper.comgateMethod('Google Pay'));
        Assert.areEqual('Comgate - Apple Pay', DKD_PaymentMethodMapper.comgateMethod('Apple Pay'));
        Assert.areEqual('Comgate - PayPal', DKD_PaymentMethodMapper.comgateMethod('PayPal'));
        Assert.areEqual('Comgate - Ostatní', DKD_PaymentMethodMapper.comgateMethod('SEPA Direct Debit'));
        Assert.isNull(DKD_PaymentMethodMapper.comgateMethod(null));
    }

    @IsTest
    static void darujmeMethodMapsPledgeValues() {
        Assert.areEqual('Darujme - Karta', DKD_PaymentMethodMapper.darujmeMethod('gp_webpay_charge'));
        Assert.areEqual('Darujme - Převod', DKD_PaymentMethodMapper.darujmeMethod('funds_transfer'));
        Assert.areEqual('Darujme - Bankovní tlačítko', DKD_PaymentMethodMapper.darujmeMethod('payu_transfer'));
        Assert.areEqual('Darujme - Trvalý příkaz', DKD_PaymentMethodMapper.darujmeMethod('csas_permanent_payment'));
        Assert.areEqual('Darujme - Ostatní', DKD_PaymentMethodMapper.darujmeMethod('neco_noveho'));
        Assert.areEqual('Darujme - Ostatní', DKD_PaymentMethodMapper.darujmeMethod(null));
    }

    @IsTest
    static void comgateGiftGetsPrefixedMethodOnInsert() {
        Account donor = insertDonor();

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Credit Card';
        gift.Payment_Method__c = 'CreditCard';
        gift.ProcessorReference = 'Comgate';
        insert gift;
        Test.stopTest();

        Assert.areEqual('Comgate - Karta', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void webhookUpdateRewritesMethod() {
        Account donor = insertDonor();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Credit Card';
        gift.Payment_Method__c = 'CreditCard';
        gift.ProcessorReference = 'Comgate';
        insert gift;

        Test.startTest();
        // webhook dorazi az po zalozeni daru a teprve on zna skutecnou metodu
        update new GiftTransaction(Id = gift.Id, Payment_Method__c = 'Apple Pay');
        Test.stopTest();

        Assert.areEqual('Comgate - Apple Pay', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void instalmentTakesMethodFromCommitment() {
        Account donor = insertDonor();
        GiftCommitment commitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        commitment.Payment_Method__c = 'Google Pay';
        insert commitment;

        Test.startTest();
        GiftTransaction instalment = newGift(donor.Id);
        instalment.GiftCommitmentId = commitment.Id;
        instalment.PaymentMethod = 'Unknown';
        insert instalment;
        Test.stopTest();

        Assert.areEqual('Comgate - Google Pay',
                [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :instalment.Id].PaymentMethod);
    }

    @IsTest
    static void fioGiftBecomesBankTransfer() {
        Account donor = insertDonor();
        Contact donorContact = ComgateTestFactory.getContact();
        insert donorContact;
        Campaign campaign = new Campaign(Name = 'Test kampan', IsActive = true);
        insert campaign;
        CRMforNonProfit__Transaction__c fpackTransaction = new CRMforNonProfit__Transaction__c(
                CRMforNonProfit__Transaction_Amount__c = 500,
                CRMforNonProfit__Transaction_Date__c = Date.today(),
                CRMforNonProfit__Contact__c = donorContact.Id,
                CRMforNonProfit__Campaign__c = campaign.Id
        );
        insert fpackTransaction;

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Bank Transfer';
        gift.npc_bridge__SourceFpackTransaction__c = fpackTransaction.Id;
        insert gift;
        Test.stopTest();

        Assert.areEqual('Bankovní převod', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void darujmeGiftUsesPledgeMethod() {
        Account donor = insertDonor();
        CRMforNonProfit__Darujme_Pledge__c pledge = new CRMforNonProfit__Darujme_Pledge__c(
                CRMforNonProfit__Payment_Method__c = 'funds_transfer',
                CRMforNonProfit__Amount__c = 500,
                CRMforNonProfit__Pledge_ID__c = 900001
        );
        insert pledge;
        CRMforNonProfit__Darujme_Transaction__c darujmeTransaction = new CRMforNonProfit__Darujme_Transaction__c(
                CRMforNonProfit__Pledge__c = pledge.Id,
                CRMforNonProfit__Received_Amount__c = 500,
                CRMforNonProfit__Transaction_ID__c = 900001
        );
        insert darujmeTransaction;

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Darujme';
        gift.npc_bridge__Darujme_Transaction__c = darujmeTransaction.Id;
        insert gift;
        Test.stopTest();

        Assert.areEqual('Darujme - Převod', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void manualGiftIsLeftAlone() {
        Account donor = insertDonor();

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Cash';
        insert gift;
        Test.stopTest();

        Assert.areEqual('Cash', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void migrateLeavesCleanDataAlone() {
        Account donor = insertDonor();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Credit Card';
        gift.Payment_Method__c = 'CreditCard';
        gift.ProcessorReference = 'Comgate';
        insert gift;

        Test.startTest();
        Integer changed = DKD_PaymentMethodMapper.migrate();
        Test.stopTest();

        // trigger uz hodnotu srovnal pri insertu, migrace tedy nema co delat
        Assert.areEqual(0, changed);
    }

    @IsTest
    static void failedPaymentFallsBackToDonorChoice() {
        Account donor = insertDonor();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Unknown';
        gift.ProcessorReference = 'Comgate';
        insert gift;
        // brana metodu nikdy nenahlasila, volba darce zustala jen v payloadu formulare
        insert new Payment_Reference__c(
                Gift_Transaction__c = gift.Id,
                JSON_Payment_Wrapper__c = '{"donationType":"oneoff","donationValue":"1000","paymentOption":"card"}'
        );

        Test.startTest();
        update new GiftTransaction(Id = gift.Id, PaymentMethod = 'Unknown', OriginalAmount = 600);
        Test.stopTest();

        Assert.areEqual('Comgate - Karta', [SELECT PaymentMethod FROM GiftTransaction WHERE Id = :gift.Id].PaymentMethod);
    }

    @IsTest
    static void repeatedRunKeepsDerivedValue() {
        Account donor = insertDonor();
        GiftTransaction gift = newGift(donor.Id);
        gift.PaymentMethod = 'Credit Card';
        gift.ProcessorReference = 'Comgate';
        insert gift;

        Test.startTest();
        List<GiftTransaction> again = [
                SELECT Id, PaymentMethod, Payment_Method__c, ProcessorReference,
                        Comgate_Transaction_Id__c, Comgate_Variable_Symbol__c,
                        GiftCommitmentId, npc_bridge__Darujme_Transaction__c,
                        npc_bridge__SourceFpackTransaction__c
                FROM GiftTransaction WHERE Id = :gift.Id
        ];
        DKD_PaymentMethodMapper.apply(again);
        DKD_PaymentMethodMapper.apply(again);
        Test.stopTest();

        // druhy pruchod uz nema surovou metodu k dispozici a nesmi si hodnotu prepsat na Ostatni
        Assert.areEqual('Comgate - Karta', again[0].PaymentMethod);
    }

    @IsTest
    static void migrateSchedulesTakesMethodFromCommitment() {
        Account donor = insertDonor();
        GiftCommitment commitment = ComgateTestFactory.getGiftCommitment(donor.Id);
        commitment.Payment_Method__c = 'Apple Pay';
        insert commitment;
        GiftCommitmentSchedule schedule = ComgateTestFactory.getGiftCommitmentSchedule(commitment.Id);
        schedule.PaymentMethod = 'Unknown';
        insert schedule;

        Test.startTest();
        Integer changed = DKD_PaymentMethodMapper.migrateSchedules();
        Test.stopTest();

        Assert.areEqual(1, changed);
        Assert.areEqual('Comgate - Apple Pay',
                [SELECT PaymentMethod FROM GiftCommitmentSchedule WHERE Id = :schedule.Id].PaymentMethod);
    }
}
