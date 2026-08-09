/**
 * Created by LukášGregora on 24/11/2023.
 */

public with sharing class StripeCheckoutSessionRequestWrapper {
    @AuraEnabled public String currency_x;
    public String return_url;
    public String client_reference_id;
    public String mode;
    public String customer_email;
    public String[] payment_method_types;
    public String stripe_customer_id;
    public String paymentOption; //card,paypal,paymentOption,sepa_debit
    public Decimal amount;

    public StripeCheckoutSessionRequestWrapper(String referenceId, DonationPagePaymentWrapper paymentWrapper, Account donor){
        this.currency_x = 'CZK';
        this.return_url = paymentWrapper.redirectURL + '?status=success';
        this.client_reference_id = referenceId;
        this.customer_email = donor?.PersonEmail;
        this.stripe_customer_id = donor?.Stripe_Customer_Id__c;
        this.amount = paymentWrapper.donationValue * StripeUtil.currencyMultiplier(this.currency_x);
        this.mode = paymentWrapper.donationType; //oneoff - recurring_monthly - recurring_yearly
        this.paymentOption = paymentWrapper.paymentOption;
        this.payment_method_types = getPaymentMethods(paymentWrapper.paymentOption);
    }

    private String[] getPaymentMethods(String selectedMethod){
        String[] methods = new String[]{};

        if(selectedMethod == null) selectedMethod = 'card';
        switch on selectedMethod{
            when 'card'{
                methods.add('card');
            }
            when 'paypal'{
                methods.add('paypal');
            }
            when 'sepadirectdebit'{
                methods.add('sepa_debit');
            }
        }
        return methods;
    }
    
    private String getMode(){
        //Docs for "Setup" mode
        //https://stripe.com/docs/payments/save-and-reuse
        if(this.mode == 'oneoff'){
            return '&mode=payment'
                    + '&line_items[0][price_data][currency]=' + this.currency_x
                    + '&line_items[0][price_data][product_data][name]=' + 'Jednorázový dar'
                    + '&line_items[0][price_data][unit_amount]=' + this.amount
                    + '&line_items[0][quantity]=1'
                    + '&payment_intent_data[metadata][payment_reference]=' + this.client_reference_id
                    + '&submit_type=donate';
        } else if (this.mode == 'recurring_monthly') {
            return '&mode=setup'
                    + '&consent_collection[terms_of_service]=required'
                    + '&custom_text[terms_of_service_acceptance][message]=' + 'Souhlasím s úhradou měsíčního daru ve výši ' + this.amount / StripeUtil.currencyMultiplier(this.currency_x) + ' ' + this.currency_x + ' Českému červenému kříži.';
        } else {
            return '&mode=setup'
                    + '&consent_collection[terms_of_service]=required'
                    + '&custom_text[terms_of_service_acceptance][message]=' + 'Souhlasím s úhradou ročního daru ve výši ' + this.amount / StripeUtil.currencyMultiplier(this.currency_x) + ' ' + this.currency_x + ' Českému červenému kříži.';

        }
    }

    public String serializeWrapper(){
        String returnString = 'currency=' + this.currency_x 
                + '&client_reference_id=' + this.client_reference_id
                + '&locale=cs'
                + '&return_url=' + this.return_url
                + (stripe_customer_id != null ? '&customer=' + this.stripe_customer_id : '&customer_creation=always&customer_email=' + this.customer_email)
                + '&metadata[payment_reference]=' + this.client_reference_id
                +  getMode()
                +  getPaymentMethodsString()
                + '&ui_mode=embedded'
                +  fillStripePaymentOptions(this.payment_method_types);
        return returnString;
        //return JSON.serialize(this).replaceAll('currency_x','currency');
    }

    private String fillStripePaymentOptions(String[] allowedMethods){
        String concatString = '';
        for(Integer i = 0; i < allowedMethods.size(); i++){
            concatString += '&payment_method_types[' + i + ']=' + allowedMethods[i];
        }
        return concatString;
    }
    
    private String getPaymentMethodsString(){
        String returnString = '';
        for(Integer i = 0; i < this.payment_method_types.size(); i++){
            returnString += '&payment_method_types[' + i + ']=' + this.payment_method_types[i];
        }
        return returnString;
    }
}