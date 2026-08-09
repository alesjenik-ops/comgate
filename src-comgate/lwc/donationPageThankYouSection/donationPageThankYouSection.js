import { LightningElement, api } from 'lwc';
import DONATION_PAGE_IMAGES from '@salesforce/resourceUrl/DonationPageImages';

export default class DonationPageThankYouSection extends LightningElement {
    @api thankYouText;
    
    iconFootprint = DONATION_PAGE_IMAGES + '/icons/icon-footprint.svg?v2';

}