@IsTest
private class ComgatePaymentRequestWrapperTest {

    private static DonationPagePaymentWrapper wrapper(String donationType, Decimal amount) {
        DonationPagePaymentWrapper paymentWrapper = new DonationPagePaymentWrapper();
        paymentWrapper.donationType = donationType;
        paymentWrapper.donationValue = amount;
        paymentWrapper.currencyIsoCode = 'CZK';
        paymentWrapper.paymentOption = 'card';
        paymentWrapper.redirectURL = 'https://darci.darujemekrouzky.cz/s/widget-landing';
        return paymentWrapper;
    }

    @IsTest
    static void paidUrlCarriesAmountAndFrequency() {
        Account donor = new Account(FirstName = 'Jana', LastName = 'Darcova', PersonEmail = 'jana@example.com');

        ComgatePaymentRequestWrapper request = new ComgatePaymentRequestWrapper(wrapper('oneoff', 500), donor, 'Dar');

        Assert.areEqual(
                'https://darci.darujemekrouzky.cz/s/widget-landing?status=success&id=${id}&refId=${refId}&frequency=oneoff&amount=500',
                request.url_paid);
        Assert.areEqual('https://darci.darujemekrouzky.cz/s/widget-landing', request.url_cancelled,
                'Zrusena platba castku na dekovaci stranku nenese');
    }

    @IsTest
    static void monthlyAndDecimalAmount() {
        Assert.areEqual('&frequency=monthly&amount=150.5',
                ComgatePaymentRequestWrapper.donationParams(wrapper('recurring_monthly', 150.50)));
        Assert.areEqual('&frequency=oneoff',
                ComgatePaymentRequestWrapper.donationParams(wrapper('oneoff', null)));
    }
}
