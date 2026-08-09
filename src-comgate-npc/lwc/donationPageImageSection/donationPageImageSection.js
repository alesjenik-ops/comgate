/**
 * Created by LukášGregora on 27/06/2023.
 */

import { LightningElement, api } from 'lwc';

export default class DonationPageImageSection extends LightningElement {
    @api imageUrl;
    @api imageAltLabel;
    @api imageHeight;
    
    get firstImageUrl(){
        return `/sfsites/c/resource/${this.imageUrl}`;
    }
    
    get imageStyle(){
        return `height: ${this.imageHeight || 500}px;`;
    }
    
}