/**
 * Created by LukášGregora on 07/10/2022.
 */

import { LightningElement, api } from 'lwc';

export default class DonationPageVideoSection extends LightningElement {
    @api videoUrl;
    @api textBelowVideo;
}