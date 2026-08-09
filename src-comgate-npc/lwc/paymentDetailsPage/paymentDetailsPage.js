/**
 * Created by LukášGregora on 24.05.2025.
 */

import { LightningElement, api } from 'lwc';

export default class PaymentDetailsPage extends LightningElement {
    @api cardTitle = 'Platební údaje';
    @api qrPayload;
    @api receiverName;
    @api bankAccount;
    @api iban;
    @api variableSymbol;
    @api amount; // Should be a number
    @api currency = 'CZK';
    @api instructionsTitle = 'Pokyny pro bankovní převod:';
    @api supportEmail;

    get displayAmount() {
        if (this.amount !== undefined && this.amount !== null) {
            // You might want to format the amount further (e.g., to 2 decimal places)
            // For now, just concatenating. Use Intl.NumberFormat for robust formatting.
            return `${Number(this.amount).toFixed(2)} ${this.currency}`;
        }
        return '';
    }

    get mailtoLink() {
        return this.supportEmail ? `mailto:${this.supportEmail}` : '#';
    }
}