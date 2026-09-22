@IsTest
private class DKD_AccountBlacklistTest {

    private static final String COMGATE = '2107358917/2700';
    private static final String NADACE_VIA = '2198370339/0800';
    private static final String DARCE = '1022272925/5500';

    private static void setUpSettings(String blacklist) {
        insert new CRMforNonProfit__NNOSettings__c(CRMforNonProfit__Account_Num_Blacklist__c = blacklist);
        DKD_AccountBlacklist.resetCache();
    }

    private static CRMforNonProfit__Transaction__c insertFpackTransaction(String sourceAccount) {
        Contact donorContact = ComgateTestFactory.getContact();
        insert donorContact;
        Campaign campaign = new Campaign(Name = 'Test kampan', IsActive = true);
        insert campaign;
        CRMforNonProfit__Transaction__c fpackTransaction = new CRMforNonProfit__Transaction__c(
                CRMforNonProfit__Transaction_Amount__c = 500,
                CRMforNonProfit__Transaction_Date__c = Date.today(),
                CRMforNonProfit__Source_Account_Number__c = sourceAccount,
                CRMforNonProfit__Contact__c = donorContact.Id,
                CRMforNonProfit__Campaign__c = campaign.Id
        );
        insert fpackTransaction;
        return fpackTransaction;
    }

    private static GiftTransaction pairedGift(Id donorId, Id fpackTransactionId, String sourceAccount) {
        return new GiftTransaction(
                Name = 'Donation',
                Status = 'Paid',
                DonorId = donorId,
                TransactionDate = Date.today(),
                TransactionDueDate = Date.today(),
                OriginalAmount = 500,
                PaymentMethod = 'Bank Transfer',
                npc_bridge__SourceFpackTransaction__c = fpackTransactionId,
                npc_bridge__Source_Account_Number__c = sourceAccount
        );
    }

    @IsTest
    static void recognisesBlacklistedNumbers() {
        setUpSettings(COMGATE + '\n' + NADACE_VIA);

        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted(COMGATE));
        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted(NADACE_VIA));
        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted(' ' + COMGATE + ' '), 'Mezery nesmi rozhodovat');
        Assert.isFalse(DKD_AccountBlacklist.isBlacklisted(DARCE));
        Assert.isFalse(DKD_AccountBlacklist.isBlacklisted(null));
        Assert.isFalse(DKD_AccountBlacklist.isBlacklisted(''));
    }

    @IsTest
    static void acceptsSeveralSeparatorsAndBareNumbers() {
        setUpSettings('2107358917; 2198370339/0800 , 123456789/0100');

        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted(COMGATE), 'Zapis bez kodu banky musi platit taky');
        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted(NADACE_VIA));
        Assert.isTrue(DKD_AccountBlacklist.isBlacklisted('123456789/0100'));
        Assert.isFalse(DKD_AccountBlacklist.isBlacklisted(DARCE));
    }

    @IsTest
    static void settlementGiftIsDiscardedOnInsert() {
        setUpSettings(COMGATE + '\n' + NADACE_VIA);
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
        CRMforNonProfit__Transaction__c zuctovani = insertFpackTransaction(NADACE_VIA);

        Test.startTest();
        GiftTransaction gift = pairedGift(donor.Id, zuctovani.Id, NADACE_VIA);
        insert gift;
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM GiftTransaction WHERE Id = :gift.Id],
                'Zuctovani brany neni dar a nesmi v CRM zustat');
        Assert.areEqual(1, [SELECT COUNT() FROM CRMforNonProfit__Transaction__c WHERE Id = :zuctovani.Id],
                'Bankovni transakce zustava, jen z ni neni dar');
    }

    @IsTest
    static void donorGiftSurvives() {
        setUpSettings(COMGATE + '\n' + NADACE_VIA);
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
        CRMforNonProfit__Transaction__c platba = insertFpackTransaction(DARCE);

        Test.startTest();
        GiftTransaction gift = pairedGift(donor.Id, platba.Id, DARCE);
        insert gift;
        Test.stopTest();

        Assert.areEqual(1, [SELECT COUNT() FROM GiftTransaction WHERE Id = :gift.Id]);
    }

    @IsTest
    static void emptyBlacklistDiscardsNothing() {
        setUpSettings(null);
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
        CRMforNonProfit__Transaction__c zuctovani = insertFpackTransaction(NADACE_VIA);

        Test.startTest();
        GiftTransaction gift = pairedGift(donor.Id, zuctovani.Id, NADACE_VIA);
        insert gift;
        Integer discarded = DKD_AccountBlacklist.discardExisting();
        Test.stopTest();

        Assert.areEqual(0, discarded);
        Assert.areEqual(1, [SELECT COUNT() FROM GiftTransaction WHERE Id = :gift.Id]);
    }
}
