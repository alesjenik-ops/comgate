@IsTest
private class DKD_GiftTransactionDatesTest {

    private static Account insertDonor() {
        Account donor = ComgateTestFactory.getDonor();
        insert donor;
        return donor;
    }

    private static GiftTransaction newGift(Id donorId, String paymentOption) {
        return new GiftTransaction(
                Name = 'Test Gift',
                Status = 'Unpaid',
                DonorId = donorId,
                TransactionDueDate = Date.today(),
                OriginalAmount = 500,
                PaymentMethod = 'Credit Card',
                Payment_Method__c = paymentOption,
                ProcessorReference = 'Comgate'
        );
    }

    @IsTest
    static void bankTransferGetsExpectedDate() {
        Account donor = insertDonor();

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id, 'Bank Transfer');
        insert gift;
        Test.stopTest();

        GiftTransaction saved = [
                SELECT PaymentMethod, TransactionDate, TransactionDueDate
                FROM GiftTransaction WHERE Id = :gift.Id
        ];
        Assert.areEqual('Comgate - Převod', saved.PaymentMethod);
        Assert.areEqual(saved.TransactionDueDate, saved.TransactionDate,
                'Nezaplaceny prevod musi mit ocekavane datum, jinak ho parovani vypisu nenajde');
    }

    @IsTest
    static void cardGiftKeepsEmptyDate() {
        Account donor = insertDonor();

        Test.startTest();
        GiftTransaction gift = newGift(donor.Id, 'CreditCard');
        insert gift;
        Test.stopTest();

        GiftTransaction saved = [SELECT PaymentMethod, TransactionDate FROM GiftTransaction WHERE Id = :gift.Id];
        Assert.areEqual('Comgate - Karta', saved.PaymentMethod);
        Assert.isNull(saved.TransactionDate, 'U karty datum plni az webhook');
    }

    @IsTest
    static void paidGiftKeepsItsOwnDate() {
        Account donor = insertDonor();
        GiftTransaction gift = newGift(donor.Id, 'Bank Transfer');
        insert gift;

        Test.startTest();
        update new GiftTransaction(Id = gift.Id, Status = 'Paid', TransactionDate = Date.today().addDays(-3));
        Test.stopTest();

        Assert.areEqual(Date.today().addDays(-3),
                [SELECT TransactionDate FROM GiftTransaction WHERE Id = :gift.Id].TransactionDate,
                'Skutecne datum platby z vypisu se nesmi prepsat splatnosti');
    }

    @IsTest
    static void backfillFillsOnlyBankTransfers() {
        Account donor = insertDonor();
        // dar bez platebni metody trigger nezmeni, takze zustane bez data a backfill ho taky mine
        GiftTransaction manual = new GiftTransaction(
                Name = 'Rucni dar', Status = 'Unpaid', DonorId = donor.Id,
                TransactionDueDate = Date.today(), OriginalAmount = 100, PaymentMethod = 'Cash'
        );
        insert manual;

        Test.startTest();
        Integer filled = DKD_GiftTransactionDates.backfill();
        Test.stopTest();

        Assert.areEqual(0, filled);
        Assert.isNull([SELECT TransactionDate FROM GiftTransaction WHERE Id = :manual.Id].TransactionDate);
    }
}
