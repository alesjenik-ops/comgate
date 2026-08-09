/**
 * Created by LukášGregora on 10.07.2025.
 */

import { LightningElement, wire } from 'lwc';
import { subscribe, MessageContext } from 'lightning/messageService';
import donationPageCampaignSelection from '@salesforce/messageChannel/donationPageCampaignSelection__c';
import getCampaignDetail from '@salesforce/apex/DonationPageController.getCampaignDetail';

export default class DonationPageCampaignDetail extends LightningElement {
    recordId;

    @wire(MessageContext) messageContext;

    @wire(getCampaignDetail, {recordId : '$recordId'})
    wiredCampaign;

    connectedCallback() {
        this.subscribeToMessageChannel();
    }

    subscribeToMessageChannel() {
        this.subscription = subscribe(
            this.messageContext,
            donationPageCampaignSelection,
            (message) => this.handleMessage(message)
        );
    }

    handleMessage(message) {
        console.log('Message received:', message.recordId);
        this.recordId = message.recordId;
    }

}