/**
 * Created by LukášGregora on 07/10/2022.
 */

import { LightningElement, api } from 'lwc';
import DONATION_PAGE_IMAGES from '@salesforce/resourceUrl/DonationPageImages';


export default class DonationPageValuesSection extends LightningElement {
    @api title;
    @api subtitle;
    @api firstBoxValue;
    @api firstBoxText;
    @api secondBoxValue;
    @api secondBoxText;
    @api thirdBoxValue;
    @api thirdBoxText;
    @api fourthBoxValue;
    @api fourthBoxText;
    
    iconWave = DONATION_PAGE_IMAGES + '/icons/icon-wave.svg?v2';
    bigPawBackground = DONATION_PAGE_IMAGES + '/icons/big-paw.svg?v2';
}