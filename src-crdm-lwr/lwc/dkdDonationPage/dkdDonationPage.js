// Hlavni darovaci stranka pro LWR site - port Aura theme layoutu DonationPageLayout
// s komponentami DonationPageHeader, DonationPageForm, donationPageCampaignDetail a DonationPageFooter.
// Light DOM, aby puvodni CSS (prevzate beze zmen) sedelo na stejny DOM jako v Aura.
import { LightningElement, api, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import basePath from '@salesforce/community/basePath';
import getCampaignDetail from '@salesforce/apex/DonationPageController.getCampaignDetail';
import SITE_CSS from '@salesforce/resourceUrl/DkdLwrSiteCss';
import BACKGROUND from '@salesforce/resourceUrl/DonationPageBackground';
import DONATION_PAGE_IMAGES from '@salesforce/resourceUrl/DonationPageImages';
import { injectDonationFonts } from 'c/donationFonts';

export default class DkdDonationPage extends LightningElement {
    static renderMode = 'light';

    // ===== hlavicka =====
    @api headerTitle = 'Darujte kroužky dětem';
    @api headerSubTitle = 'Pomáháme rodinám zaplatit volnočasové aktivity pro děti.';
    @api headerTitleStyle = '';
    @api headerSubTitleStyle = '';
    @api headerCss = '';
    @api headerImage = 'DonationPageHeaderImage';
    @api headerImageCss = '';
    @api logoImage = 'DonationPageHeaderLogo';
    @api logoHref = 'https://darujemekrouzky.cz/';
    // ===== paticka =====
    @api footerLogoImage = 'DonationPageFooterLogo';
    @api footerLogoHref = 'https://darujemekrouzky.cz/';
    // ===== formular (preposila se do c-dkd-donation-form) =====
    @api campaignId = '';
    @api formHeaderLabel = 'Darujte kroužky dětem';
    @api formHeaderSubLabel = 'Pomáháme rodinám zaplatit volnočasové aktivity pro děti.';
    @api donationTypeOneOff = false;
    @api donationTypeMonthly = false;
    @api donationTypeYearly = false;
    @api defaultDonationType = 'oneoff';
    @api amountsOneOff = '20;50;100;other';
    @api amountsMonthly = '20;50;100;other';
    @api amountsYearly = '200;500;1000;other';
    @api fieldSetSelection = 'DonationPageFieldSet';
    @api paymentCard = false;
    @api paymentBankTransfer = false;
    @api defaultPaymentOption = 'card';
    @api thankYouLabel = 'Děkujeme za Vaší podporu.';
    @api thankYouPageUrl = 'https://www.darujemekrouzky.cz/dekujeme/';
    @api disabledCampaignSelection = false;
    @api receiverName = 'Česká rada dětí a mládeže';
    @api supportEmail = '';

    selectedCampaignId;
    campaignDetail = '';

    connectedCallback() {
        injectDonationFonts();
        loadStyle(this, SITE_CSS).catch((e) => {
            // eslint-disable-next-line no-console
            console.error('DkdLwrSiteCss failed', e);
        });
    }

    @wire(getCampaignDetail, { recordId: '$selectedCampaignId' })
    wiredCampaign({ data }) {
        this.campaignDetail = data && data.Donation_Page_Detail__c ? data.Donation_Page_Detail__c : '';
    }

    renderedCallback() {
        // Rich text kampane - lwc:inner-html platforma nepodporuje, v light DOM se vlozi rucne
        const box = this.querySelector('.dkd-campaign-detail-html');
        if (box && box.dataset.html !== this.campaignDetail) {
            box.innerHTML = this.campaignDetail || '';
            box.dataset.html = this.campaignDetail || '';
        }
    }

    handleCampaignChange(event) {
        this.selectedCampaignId = event.detail.recordId;
    }

    resource(name) {
        if (!name) return '';
        if (/^https?:\/\//.test(name) || name.startsWith('/')) return name;
        return basePath + '/sfsites/c/resource/' + name;
    }

    get layoutStyle() { return '--dkd-bg-image: url(' + BACKGROUND + ');'; }
    get headerStyle() { return this.headerCss || ''; }
    get headerBackgroundStyle() { return 'background-image: url(' + this.resource(this.headerImage) + ');' + (this.headerImageCss || ''); }
    get logoUrl() { return this.resource(this.logoImage); }
    get footerLogoStyle() { return 'background-image: url(' + this.resource(this.footerLogoImage) + ');'; }
    get emailIcon() { return DONATION_PAGE_IMAGES + '/social-icons/email_icon.svg'; }
    get hasCampaignDetail() { return !!this.campaignDetail; }
    get termsUrl() { return basePath + '/obchodni-podminky'; }
    get privacyUrl() { return basePath + '/ochrana-osobnich-udaju'; }
}