/**
 * Created by LukášGregora on 17/11/2022.
 */

import { LightningElement, api } from 'lwc';

export default class DonationPageImagesSection extends LightningElement {
    @api firstImageLabel;
    @api firstImagePath;
    @api secondImageLabel;
    @api secondImagePath;
    @api thirdImageLabel;
    @api thirdImagePath;
    
    get firstImageUrl(){
        return `/sfsites/c/resource/${this.firstImagePath}`;
    }
    
    get secondImageUrl(){
        return `/sfsites/c/resource/${this.secondImagePath}`;
    }
    
    get thirdImageUrl(){
        return `/sfsites/c/resource/${this.thirdImagePath}`;
    }
}