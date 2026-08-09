//https://apidoc.comgate.cz/api/rest/#operation/v2-0-create
public with sharing class ComgatePaymentRequestWrapper {
    public Boolean test;
    public String country; //two digit country code
    public Decimal price;
    public String curr; //CZK, EUR, PLN, HUF, USD, GBP, RON, NOK, SEK
    public String label;
    public String refId;
    public String method;
    public String account;
    public String email;
    public String phone;
    public String fullname;
    public String billingAddrCity;
    public String billingAddrStreet;
    public String billingAddrPostalCode;
    public String billingAddrCountry;
    public String delivery;
    public String homeDeliveryCity;
    public String homeDeliveryPostalCode;
    public String homeDeliveryCountry;
    public String category;
    public String name;
    public String lang;
    public Boolean preauth;
    public Boolean initRecurring;
    public Boolean verification;
    public String expirationTime;
    public Boolean dynamicExpiration;
    public String url_paid;
    public String url_cancelled;
    public String url_pending;
    public Boolean chargeUnregulatedCardFees;
    public Boolean enableApplePayGooglePay;


    public ComgatePaymentRequestWrapper(){
        this.test = !ComgateUtil.runningInASandbox;
        this.method = 'ALL';
        this.lang = 'cs';
        this.enableApplePayGooglePay = true;
    }

    public ComgatePaymentRequestWrapper(DonationPagePaymentWrapper paymentWrapper, Contact con){
        this();
        this.price = paymentWrapper.donationValue * 100;
        this.curr = paymentWrapper.currencyIsoCode;
        this.label = 'Comgate Test Donation';
        this.refId = paymentWrapper.paymentReferenceId;
        this.email = con.Email;
        this.phone = con.MobilePhone;
        this.fullname = con.FirstName + '' + con.LastName;
        this.initRecurring = paymentWrapper.donationType != 'oneoff';
        this.url_paid = paymentWrapper.redirectURL + '?status=success&id=${id}&refId=${refId}';
        this.url_cancelled = paymentWrapper.redirectURL;
        this.url_pending = paymentWrapper.redirectURL;
        this.method = getPaymentMethod(paymentWrapper.paymentOption);
    }

    private static String getPaymentMethod(String paymentOption){
        if(paymentOption == null) return paymentOption;
        switch on paymentOption{
            when 'card'{
                return 'CARD_ALL + APPLEPAY_REDIRECT + GOOGLEPAY_REDIRECT';
            }
        }
        return null;
    }
}