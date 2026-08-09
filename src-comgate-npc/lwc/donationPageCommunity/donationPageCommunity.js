import { LightningElement } from 'lwc';
import FONTS from '@salesforce/resourceUrl/DonationPageFonts';
import HERO_IMAGE from '@salesforce/resourceUrl/DonationPageHeaderImage';
import LOGO from '@salesforce/resourceUrl/DonationPageHeaderLogo';
import CAMPAIGN_PHOTO from '@salesforce/resourceUrl/DonationPageCampaignPhoto';
import BACKGROUND_TILE from '@salesforce/resourceUrl/DonationPageBackgroundTile';
import getFieldSetWrapper from '@salesforce/apex/DonationPageController.getFieldSetWrapper';
import getReferenceId from '@salesforce/apex/DonationPageController.getReferenceId';
import createComgatePayment from '@salesforce/apex/DonationPageController.createComgatePayment';
import createRelatedRecords from '@salesforce/apex/DonationPageController.createRelatedRecords';
import justCreateRecords from '@salesforce/apex/DonationPageController.justCreateRecords';

// Hardcoded configuration mirroring the original builder setup of c:DonationPageForm
const CAMPAIGN_ID = '701Te00000gDlc7IAC';
const FIELD_SET_NAME = 'DonationPageFieldSet';
const RECEIVER_NAME = 'Česká rada dětí a mládeže';
const SUPPORT_EMAIL = 'info@darujemekrouzky.cz';
const DEFAULT_DONATION_TYPE = 'oneoff';
const DEFAULT_PAYMENT_OPTION = 'card';
const DONATION_AMOUNTS = {
    oneoff: ['20', '50', '100', 'other'],
    recurring_monthly: ['20', '50', '100', 'other'],
    recurring_yearly: ['200', '500', '1000', 'other']
};
const DONATION_TYPE_OPTIONS = [
    { label: 'Jednorázově', value: 'oneoff' },
    { label: 'Měsíčně', value: 'recurring_monthly' },
    { label: 'Ročně', value: 'recurring_yearly' }
];
const PAYMENT_OPTIONS = [
    { label: 'Platební karta', value: 'card' },
    { label: 'Platební převod', value: 'banktransfer' }
];
const ACCOUNT_TYPE_OPTIONS = [
    { label: 'Fyzická osoba', value: 'person' },
    { label: 'Právnická osoba', value: 'legal' }
];
const SPINNER_TEXTS = {
    loading: 'Načítání…',
    processing: 'Zpracováváme…',
    redirecting: 'Přesměrováváme na platební bránu…'
};
const FONT_STYLE_ID = 'dkd-community-fonts';
const FONT_FILES = [
    { weight: 400, file: 'fira-sans-v18-latin_latin-ext-regular.woff2' },
    { weight: 500, file: 'fira-sans-v18-latin_latin-ext-500.woff2' },
    { weight: 700, file: 'fira-sans-v18-latin_latin-ext-700.woff2' },
    { weight: 800, file: 'fira-sans-v18-latin_latin-ext-800.woff2' }
];

export default class DonationPageCommunity extends LightningElement {
    spinner = false;
    spinnerMessage = 'loading';
    success = false;
    currentStep = 'first'; // first, personDetails, paymentMethodsSelection, paymentMethods, last
    donationWrapperOpened = true;
    errorMessage = '';
    amountError = '';

    campaignId = CAMPAIGN_ID;
    campaigns = [];
    countryOptions = [];
    formHeaderLabel = 'Daruj kroužky pro děti';
    formHeaderSubLabel = 'Podporujeme rodiny v ČR, které jsou v tíživé finanční situaci.';
    thankYouLabel = 'Děkujeme za Vaší podporu.';
    thankYouText = '';
    receiverName = RECEIVER_NAME;
    supportEmail = SUPPORT_EMAIL;

    isPersonAccount = true;
    donor = { sobjectType: 'Account' };
    contactPerson = { sobjectType: 'Contact' };

    donationOptionSelected = '';
    paymentWrapper = {
        donationType: DEFAULT_DONATION_TYPE,
        donationValue: 50,
        paymentOption: DEFAULT_PAYMENT_OPTION,
        currencyIsoCode: 'CZK',
        allowedPaymentMethods: PAYMENT_OPTIONS.map((item) => item.value)
    };
    paymentReferenceId = '';
    paymentUrl = null;
    bankAccountDetails = {};

    showDonateButton = false;

    _boundOnScroll;
    _boundOnMessage;

    /* ================= lifecycle ================= */

    connectedCallback() {
        this.injectFonts();

        const status = this.getUrlParameter('status');
        const urlCampaignId = this.getUrlParameter('campaignId');
        const donorId = this.getUrlParameter('donorId');

        if (donorId) {
            this.donor = { ...this.donor, Id: donorId };
        }
        if (window.frameElement) {
            parent.postMessage({ id: 'onSuccessPage', data: { isSuccess: true } }, '*');
            return;
        }
        if (status && status === 'success') {
            this.success = true;
            this.currentStep = 'last';
            this.pushPurchaseDataLayer();
        }
        if (urlCampaignId) {
            this.campaignId = urlCampaignId;
        }

        this.paymentWrapper = {
            ...this.paymentWrapper,
            redirectURL: location.protocol + '//' + location.host + location.pathname
        };

        this.setDefaultDonationAmount(DEFAULT_DONATION_TYPE);
        this.loadFieldSets();

        this._boundOnScroll = this.onWindowScroll.bind(this);
        this._boundOnMessage = this.onWindowMessage.bind(this);
        window.addEventListener('scroll', this._boundOnScroll);
        window.addEventListener('message', this._boundOnMessage);
    }

    disconnectedCallback() {
        if (this._boundOnScroll) window.removeEventListener('scroll', this._boundOnScroll);
        if (this._boundOnMessage) window.removeEventListener('message', this._boundOnMessage);
    }

    renderedCallback() {
        // Keep uncontrolled inputs in sync with state when a step re-renders
        this.template.querySelectorAll('.f-input').forEach((el) => {
            const record = el.dataset.obj === 'contact' ? this.contactPerson : this.donor;
            const value = record[el.dataset.field];
            const stringValue = value === undefined || value === null ? '' : String(value);
            if (el.value !== stringValue) el.value = stringValue;
        });
    }

    injectFonts() {
        if (document.getElementById(FONT_STYLE_ID)) return;
        const style = document.createElement('style');
        style.id = FONT_STYLE_ID;
        style.textContent = FONT_FILES.map(
            (font) =>
                `@font-face{font-family:'Fira Sans';font-style:normal;font-weight:${font.weight};` +
                `font-display:swap;src:url('${FONTS}/${font.file}') format('woff2')}`
        ).join('\n');
        document.head.appendChild(style);
    }

    /* ================= data loading ================= */

    loadFieldSets() {
        this.spinner = true;
        this.spinnerMessage = 'loading';
        getFieldSetWrapper({
            fieldSetName: FIELD_SET_NAME,
            donorId: this.donor.Id || null,
            campaignId: this.campaignId
        })
            .then((result) => {
                const resolveBody = JSON.parse(result);
                if (resolveBody.donor) this.donor = { sobjectType: 'Account', ...resolveBody.donor };
                this.campaigns = resolveBody.campaigns || [];
                this.countryOptions = resolveBody.countryOptions || [];
                if (!this.campaignId && this.campaigns.length > 0) {
                    this.campaignId = this.campaigns[0].Id;
                }
                this.setFieldsFromSelectedCampaign(this.campaignId);
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error('loadFieldSets failed', e);
            })
            .finally(() => {
                this.spinner = false;
            });
    }

    setFieldsFromSelectedCampaign(campaignId) {
        if (campaignId == null) return;
        const selectedOption = this.campaigns.find((option) => option.Id === campaignId);
        if (!selectedOption) return;
        this.formHeaderLabel = selectedOption.Name;
        this.thankYouText = selectedOption.Donation_Page_Thank_You_Text__c || '';
    }

    /* ================= getters: styles & assets ================= */

    get pageStyle() {
        return `background-image:url(${BACKGROUND_TILE})`;
    }

    get heroStyle() {
        return `background-image:url(${HERO_IMAGE})`;
    }

    get logoUrl() {
        return LOGO;
    }

    get campaignPhotoUrl() {
        return CAMPAIGN_PHOTO;
    }

    get spinnerText() {
        return SPINNER_TEXTS[this.spinnerMessage] || SPINNER_TEXTS.processing;
    }

    /* ================= getters: steps ================= */

    get isStepFirst() {
        return this.currentStep === 'first';
    }
    get isStepPersonDetails() {
        return this.currentStep === 'personDetails';
    }
    get isStepPaymentMethodsSelection() {
        return this.currentStep === 'paymentMethodsSelection';
    }
    get isStepPaymentMethods() {
        return this.currentStep === 'paymentMethods';
    }
    get isStepLast() {
        return this.currentStep === 'last';
    }
    get isBankTransfer() {
        return this.paymentWrapper.paymentOption === 'banktransfer';
    }

    /* ================= getters: form ================= */

    get expanderClass() {
        return 'expander' + (this.donationWrapperOpened ? ' expanded' : '');
    }

    get expanderArrowClass() {
        return 'expander-arrow' + (this.donationWrapperOpened ? ' down' : ' up');
    }

    get formInnerClass() {
        return 'form-inner' + (this.donationWrapperOpened ? '' : ' hidden');
    }

    get amountOptions() {
        return DONATION_AMOUNTS[this.paymentWrapper.donationType].map((value) => ({
            value,
            label: value === 'other' ? 'Jiná' : value + ' Kč',
            cls: 'opt' + (this.donationOptionSelected === value ? ' sel' : '')
        }));
    }

    get frequencyOptions() {
        return DONATION_TYPE_OPTIONS.map((option) => ({
            ...option,
            cls: 'opt' + (this.paymentWrapper.donationType === option.value ? ' sel' : '')
        }));
    }

    get paymentOptions() {
        return PAYMENT_OPTIONS.map((option) => ({
            ...option,
            cls: 'pay-option' + (this.paymentWrapper.paymentOption === option.value ? ' sel' : '')
        }));
    }

    get accountTypeOptions() {
        return ACCOUNT_TYPE_OPTIONS.map((option) => ({
            ...option,
            cls: 'opt' + ((this.isPersonAccount ? 'person' : 'legal') === option.value ? ' sel' : '')
        }));
    }

    get amountInputDisabled() {
        return this.donationOptionSelected !== 'other';
    }

    get amountInputClass() {
        return 'amount-input' + (this.amountError ? ' invalid' : '');
    }

    get amountDisplayValue() {
        const value = this.paymentWrapper.donationValue;
        return value === undefined || value === null ? '' : String(value);
    }

    get ctaLabel() {
        const frequency =
            this.paymentWrapper.donationType === 'oneoff'
                ? 'jednorázově'
                : this.paymentWrapper.donationType === 'recurring_monthly'
                  ? 'měsíčně'
                  : 'ročně';
        const value = this.paymentWrapper.donationValue == null ? '' : this.paymentWrapper.donationValue;
        return `Ano, darovat ${value} Kč ${frequency}`;
    }

    get floatDonateClass() {
        return 'float-donate' + (this.showDonateButton ? ' show' : '');
    }

    /* ================= handlers: step 1 ================= */

    handleDonationOptionChanged(event) {
        const value = event.currentTarget.dataset.value;
        this.donationOptionSelected = value;
        this.amountError = '';
        this.paymentWrapper = {
            ...this.paymentWrapper,
            donationValue: isNaN(value) ? null : parseInt(value, 10)
        };
        if (value === 'other') {
            Promise.resolve(true).then(() => {
                const input = this.template.querySelector('[data-id="donationAmount"]');
                if (input) input.focus();
            });
        }
    }

    handleDonationTypeChanged(event) {
        const value = event.currentTarget.dataset.value;
        this.paymentWrapper = { ...this.paymentWrapper, donationType: value };
        this.setDefaultDonationAmount(value);
    }

    handleAmountInput(event) {
        this.paymentWrapper = { ...this.paymentWrapper, donationValue: event.target.value };
        this.amountError = '';
    }

    setDefaultDonationAmount(type) {
        if (!type) {
            this.donationOptionSelected = '';
            this.paymentWrapper = { ...this.paymentWrapper, donationValue: null };
            return;
        }
        const options = DONATION_AMOUNTS[type];
        let amount = null;
        if (options.length > 1) {
            amount = options[1];
        } else if (options.length === 1) {
            amount = options[0];
        }
        this.donationOptionSelected = amount + '';
        this.paymentWrapper = {
            ...this.paymentWrapper,
            donationValue: isNaN(amount) ? null : parseInt(amount, 10)
        };
    }

    handleDonationExpander() {
        this.donationWrapperOpened = !this.donationWrapperOpened;
    }

    /* ================= handlers: step 2 ================= */

    handleAccountTypeChange(event) {
        const value = event.currentTarget.dataset.value;
        this.isPersonAccount = value === 'person';
        this.donor = { sobjectType: 'Account' };
        this.contactPerson = { sobjectType: 'Contact' };
        this.errorMessage = '';
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        if (event.target.dataset.obj === 'contact') {
            this.contactPerson = { ...this.contactPerson, [field]: value };
        } else {
            this.donor = { ...this.donor, [field]: value };
        }
        event.target.classList.remove('invalid');
    }

    /* ================= handlers: step 3 ================= */

    handlePaymentOptionChange(event) {
        const value = event.currentTarget.dataset.value;
        this.paymentWrapper = { ...this.paymentWrapper, paymentOption: value };
    }

    /* ================= main flow ================= */

    handleDonate() {
        if (!this.validateForm()) return;
        this.errorMessage = '';
        const currentStep = this.currentStep;

        if (currentStep === 'first') {
            this.currentStep = 'personDetails';
            this.scrollFormTop();
            return;
        } else if (currentStep === 'personDetails') {
            this.currentStep = 'paymentMethodsSelection';
            this.scrollFormTop();
            return;
        } else if (currentStep === 'paymentMethodsSelection') {
            if (this.paymentWrapper.paymentOption === 'banktransfer') {
                this.payByBankTransfer();
                return;
            }
            this.currentStep = 'paymentMethods';
            this.scrollFormTop();
        }

        this.spinner = true;
        this.spinnerMessage = 'processing';

        const paymentWrapper = { ...this.paymentWrapper };
        if (isNaN(paymentWrapper.donationValue)) {
            paymentWrapper.donationValue = String(paymentWrapper.donationValue).replace(',', '.');
        }
        this.paymentWrapper = paymentWrapper;

        let shopperReference;
        let paymentReference;
        getReferenceId({
            donorString: JSON.stringify(this.donor),
            conString: JSON.stringify(this.contactPerson),
            isPersonAccount: this.isPersonAccount,
            campaignId: this.campaignId,
            paymentWrapperString: JSON.stringify(paymentWrapper)
        })
            .then((result) => {
                const responseObj = JSON.parse(result);
                shopperReference = responseObj.shopperReference;
                paymentReference = responseObj.paymentReference;
                if (!this.isPersonAccount) {
                    this.donor = { ...this.donor, PersonEmail: this.contactPerson.Email };
                }
                this.storePurchaseDataLayer(paymentReference);
                this.spinnerMessage = 'redirecting';
                return createComgatePayment({
                    paymentReferenceId: paymentReference,
                    donorString: JSON.stringify(this.donor),
                    campaignId: this.campaignId,
                    paymentWrapperString: JSON.stringify(this.paymentWrapper)
                });
            })
            .then((result) => {
                this.paymentReferenceId = paymentReference;
                this.fireCreateRelatedRecords(paymentReference, shopperReference);
                this.pushCheckoutDataLayer(paymentReference);

                if (result == null) {
                    this.currentStep = 'paymentMethodsSelection';
                    this.spinnerMessage = '';
                    this.spinner = false;
                    this.errorMessage =
                        'Vytvoření platby se nezdařilo, zkuste to prosím znovu.' +
                        (this.supportEmail ? ' Pokud problém přetrvává, kontaktujte ' + this.supportEmail + '.' : '');
                    return;
                }

                this.paymentUrl = result;
                window.setTimeout(() => {
                    this.spinnerMessage = '';
                    this.spinner = false;
                }, 1000);
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error(e);
                const message = this.getErrorMessage(e);
                this.errorMessage = message;
                this.onError({ name: 'HandleDonate', message });
                this.spinnerMessage = '';
                this.spinner = false;
                this.currentStep = 'paymentMethodsSelection';
            });
    }

    handleStepBack() {
        this.errorMessage = '';
        const currentStep = this.currentStep;
        if (currentStep === 'personDetails') {
            this.currentStep = 'first';
        } else if (currentStep === 'paymentMethodsSelection') {
            this.currentStep = 'personDetails';
        } else if (currentStep === 'paymentMethods') {
            this.paymentUrl = null;
            this.currentStep = 'paymentMethodsSelection';
        }
    }

    payByBankTransfer() {
        this.spinner = true;
        this.spinnerMessage = 'processing';
        this.scrollFormTop();

        justCreateRecords({
            donorString: JSON.stringify(this.donor),
            conString: JSON.stringify(this.contactPerson),
            isPersonAccount: this.isPersonAccount,
            campaignId: this.campaignId,
            paymentWrapperString: JSON.stringify(this.paymentWrapper)
        })
            .then((result) => {
                this.bankAccountDetails = result;
                this.currentStep = 'last';
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error(e);
                this.errorMessage = this.getErrorMessage(e);
            })
            .finally(() => {
                this.spinnerMessage = '';
                this.spinner = false;
            });
    }

    fireCreateRelatedRecords(paymentReferenceId, shopperReferenceId) {
        createRelatedRecords({ paymentReferenceId, shopperReferenceId }).catch((e) => {
            // eslint-disable-next-line no-console
            console.error('createRelatedRecords failed', e);
        });
    }

    getErrorMessage(e) {
        if (e && e.body) {
            if (Array.isArray(e.body) && e.body.length) return e.body[0].message;
            if (e.body.message) return e.body.message;
        }
        return (e && e.message) || 'Došlo k neočekávané chybě, zkuste to prosím znovu.';
    }

    /* ================= validation ================= */

    validateForm() {
        if (this.currentStep === 'first') {
            const rawValue = String(this.paymentWrapper.donationValue == null ? '' : this.paymentWrapper.donationValue);
            const pattern = /^([1-9][0-9]*)((,|\.)([0-9]{0,7}))?$/;
            const numericValue = parseFloat(rawValue.replace(',', '.'));
            if (!pattern.test(rawValue) || isNaN(numericValue) || numericValue < 15) {
                this.amountError = 'Zadejte prosím částku alespoň 15 Kč.';
                return false;
            }
            this.amountError = '';
            return true;
        }

        if (this.currentStep === 'personDetails') {
            let valid = true;
            this.template.querySelectorAll('.f-input').forEach((el) => {
                const value = (el.value || '').trim();
                let fieldValid = true;
                if (!el.dataset.optional && !value) fieldValid = false;
                if (value && el.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) fieldValid = false;
                el.classList.toggle('invalid', !fieldValid);
                if (!fieldValid) valid = false;
            });
            this.errorMessage = valid ? '' : 'Vyplňte prosím všechna povinná pole.';
            return valid;
        }

        return true;
    }

    /* ================= scroll & floating button ================= */

    scrollFormTop() {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    onWindowScroll() {
        const formElement = this.template.querySelector('[data-id="donationForm"]');
        this.showDonateButton = formElement != null && formElement.getBoundingClientRect().bottom < 0;
    }

    handleDonateNow() {
        const formElement = this.template.querySelector('[data-id="donationForm"]');
        if (formElement) {
            window.scrollTo({ top: formElement.offsetTop, behavior: 'smooth' });
        }
    }

    onWindowMessage(event) {
        if (event.data && event.data.id === 'onSuccessPage') {
            this.success = true;
            this.currentStep = 'last';
        }
    }

    /* ================= utilities ================= */

    getUrlParameter(sParam) {
        const sPageURL = decodeURIComponent(window.location.search.substring(1));
        const sURLVariables = sPageURL.split('&');
        for (let i = 0; i < sURLVariables.length; i++) {
            const sParameterName = sURLVariables[i].split('=');
            if (sParameterName[0] === sParam) {
                return sParameterName[1] === undefined ? true : sParameterName[1];
            }
        }
        return undefined;
    }

    /* ================= data layers (GTM + JENTIS) ================= */

    pushCheckoutDataLayer(recordId) {
        const paymentWrapper = this.paymentWrapper;

        const dataLayerObject = {
            event: 'checkout',
            ecommerce: {
                checkout: {
                    actionField: {
                        step: this.currentStep,
                        option: this.getPaymentType(paymentWrapper.paymentOption)
                    },
                    products: [
                        {
                            name: window.location.pathname,
                            id: this.getPaymentFrequency(paymentWrapper.donationType),
                            price: paymentWrapper.donationValue,
                            brand: '',
                            category: this.getPaymentType(paymentWrapper.paymentOption),
                            variant: this.getPaymentFrequency(paymentWrapper.donationType),
                            quantity: 1,
                            coupon: ''
                        }
                    ]
                }
            }
        };
        document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: dataLayerObject } }));

        const jentisObject = {
            event: 'begin_checkout',
            ecommerce: {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(paymentWrapper.donationType),
                payment_type: this.getPaymentType(paymentWrapper.paymentOption),
                items: [
                    {
                        item_name: window.location.pathname,
                        currency: paymentWrapper.currencyIsoCode,
                        price: paymentWrapper.donationValue,
                        quantity: 1
                    }
                ]
            }
        };
        document.dispatchEvent(new CustomEvent('user_interaction', { detail: jentisObject }));
    }

    pushPurchaseDataLayer() {
        const dataLayerEvents = localStorage.getItem('dataLayerEvents')
            ? JSON.parse(localStorage.getItem('dataLayerEvents'))
            : null;
        if (dataLayerEvents) {
            document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: dataLayerEvents.gtm } }));
            document.dispatchEvent(new CustomEvent('user_interaction', { detail: dataLayerEvents.jentis }));
            localStorage.removeItem('dataLayerEvents');
        }
    }

    storePurchaseDataLayer(recordId) {
        const paymentWrapper = this.paymentWrapper;
        localStorage.setItem(
            'dataLayerEvents',
            JSON.stringify({
                gtm: this.purchaseGTMEvent(recordId, paymentWrapper),
                jentis: this.purchaseJentisEvent(recordId, paymentWrapper)
            })
        );
    }

    purchaseGTMEvent(recordId, paymentWrapper) {
        return {
            event: 'purchase',
            ecommerce: {
                purchase: {
                    actionField: {
                        id: recordId,
                        affiliation: '',
                        revenue: paymentWrapper.donationValue,
                        tax: '',
                        shipping: '',
                        coupon: ''
                    },
                    products: [
                        {
                            name: window.location.pathname,
                            id: this.getPaymentFrequency(paymentWrapper.donationType),
                            category: this.getPaymentType(paymentWrapper.paymentOption),
                            brand: '',
                            price: paymentWrapper.donationValue,
                            variant: this.getPaymentFrequency(paymentWrapper.donationType),
                            quantity: 1,
                            coupon: ''
                        }
                    ]
                }
            }
        };
    }

    purchaseJentisEvent(recordId, paymentWrapper) {
        return {
            event: 'Purchase',
            ecommerce: {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(paymentWrapper.donationType),
                payment_type: this.getPaymentType(paymentWrapper.paymentOption),
                items: [
                    {
                        item_name: window.location.pathname,
                        currency: paymentWrapper.currencyIsoCode,
                        price: paymentWrapper.donationValue,
                        quantity: 1
                    }
                ]
            }
        };
    }

    onError(error) {
        error = error || {};
        // eslint-disable-next-line no-console
        console.error(error.name, error.message, error.stack);
        const paymentWrapper = this.paymentWrapper;
        const recordId = this.paymentReferenceId;

        const dataLayerObject = {
            event: 'donation_error',
            error_code: error.name,
            error_message: error.message,
            error_stack: error.stack,
            ecommerce: {
                products: [
                    {
                        name: window.location.pathname,
                        id: this.getPaymentFrequency(paymentWrapper.donationType),
                        price: paymentWrapper.donationValue,
                        brand: '',
                        category: this.getPaymentType(paymentWrapper.paymentOption),
                        variant: this.getPaymentFrequency(paymentWrapper.donationType),
                        quantity: 1,
                        coupon: ''
                    }
                ]
            }
        };
        document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: dataLayerObject } }));

        const jentisObject = {
            event: 'error',
            error_code: error.name,
            error_message: error.message,
            error_stack: error.stack,
            ecommerce: {
                transaction_id: recordId,
                campaign_name: window.location.pathname,
                currency: paymentWrapper.currencyIsoCode,
                value: paymentWrapper.donationValue,
                recurrence: this.getPaymentFrequency(paymentWrapper.donationType),
                payment_type: this.getPaymentType(paymentWrapper.paymentOption),
                items: [
                    {
                        item_name: window.location.pathname,
                        currency: paymentWrapper.currencyIsoCode,
                        price: paymentWrapper.donationValue,
                        quantity: 1
                    }
                ]
            }
        };
        document.dispatchEvent(new CustomEvent('user_interaction', { detail: jentisObject }));
    }

    getPaymentFrequency(donationType) {
        switch (donationType) {
            case 'recurring_monthly':
                return 'monthly';
            case 'oneoff':
                return 'once';
            case 'recurring_yearly':
                return 'yearly';
            default:
                return '';
        }
    }

    getPaymentType(paymentOption) {
        switch (paymentOption) {
            case 'card':
                return 'creditcard';
            case 'paypal':
                return 'paypal';
            case 'sepadirectdebit':
                return 'directdebit';
            default:
                return '';
        }
    }
}
