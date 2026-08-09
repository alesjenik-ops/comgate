import { LightningElement, api } from 'lwc';
//https://apidoc.comgate.cz/platebni-brana-v-eshopu/

export default class ComgatePaymentForm extends LightningElement {
    @api paymentUrl;

    get wrapperClass(){
        return `comgate-container ${this.paymentUrl ? 'show' : 'hide'}`;
    }

    connectedCallback(){
        console.log('paymentUrl ', this.paymentUrl);
    }

}