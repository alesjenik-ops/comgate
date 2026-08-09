/**
 * Created by LukášGregora on 15/12/2023.
 */

public with sharing class StripePaymentIntentCaptureResponse extends StripeErrorResponseWrapper{
    public Decimal amount;
    public Decimal amount_received;
    public String status;
}