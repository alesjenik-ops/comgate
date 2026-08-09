import { LightningElement, wire, api } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import getStripePublicKey from '@salesforce/apex/StripePaymentFormController.getStripePublicKey';
import updatePaymentReferenceWithRadarId from '@salesforce/apex/DonationPageController.updatePaymentReferenceWithRadarId';

export default class StripePaymentForm extends LightningElement {
    checkout;
    spinner;
    
    connectedCallback(){
        this.spinner = true;
    }
    
    @api
    async initialize(clientSecret, paymentReferenceId){

        await loadScript(this, 'https://js.stripe.com/v3/');
        const publicKey = await getStripePublicKey();
        if(publicKey){
            const stripe = Stripe(publicKey, {
                locale : 'cs'
            });
            await this.initializeStripe(clientSecret, stripe);
            await this.handleRadarSession(stripe, paymentReferenceId);
        }
    }

    async handleRadarSession(stripe, paymentReferenceId){
        const {radarSession, error} = await stripe.createRadarSession();
        console.log('radarSession ', radarSession);
        console.log('error ', error);
        await updatePaymentReferenceWithRadarId({
            paymentReferenceId,
            radarSession : radarSession.id
        })

    }
    
    handleOnComplete(){
    }
    
    async initializeStripe(clientSecret, stripe){
        this.checkout = await stripe.initEmbeddedCheckout({
            clientSecret,
            onComplete : this.handleOnComplete.bind(this)
        });
    
        // Mount Checkout
        await this.checkout.mount(this.refs.checkout);
        this.spinner = false;
    }
    
    async disconnectedCallback(){
        if(this.checkout) {
            await this.checkout.destroy();
            this.checkout = undefined;
        }
    }
}