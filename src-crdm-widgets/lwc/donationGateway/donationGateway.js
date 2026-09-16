import { LightningElement, api } from 'lwc';

/**
 * Iframe platebni brany Comgate pro darcovsky widget. Nahrazuje sdilenou komponentu
 * comgatePaymentForm, ktera ma iframe napevno 504 px a posouva ho o -250 px doleva -
 * v uzke karte na mobilu pak pretekal z karty ven. Tady se prizpusobi sirce karty.
 */
export default class DonationGateway extends LightningElement {
    @api paymentUrl;
}
