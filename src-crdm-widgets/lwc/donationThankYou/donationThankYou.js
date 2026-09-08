import { LightningElement, api } from 'lwc';

export default class DonationThankYou extends LightningElement {
    @api headline = 'Děkujeme Vám';
    @api message = 'Děkujeme za váš příspěvek.';
    @api contactText = 'Máte dotaz? Napište nám na';
    @api contactEmail = 'info@darujemekrouzky.cz';
    @api infolineTitle = 'Infolinka Darujeme kroužky dětem';
    @api infolinePhone = '+420 773 772 202';
    @api infolineHours = 'pondělí–pátek, 9–16 hodin · infolinka v českém jazyce';
    @api backLabel = 'Zpět na úvod';
    @api backUrl = 'https://www.darujemekrouzky.cz/';

    get mailtoHref() {
        return `mailto:${this.contactEmail}`;
    }

    get telHref() {
        // tel: nesnasi mezery ani zavorky
        return `tel:${String(this.infolinePhone || '').replace(/[^0-9+]/g, '')}`;
    }

    get hasBackLink() {
        return !!(this.backUrl && this.backLabel);
    }
}
