// Darovaci formular hlavni stranky pro LWR site - port Aura komponenty DonationPageForm.
// Light DOM: markup kopiruje DOM, ktery vykreslovaly Aura base komponenty (lightning:input,
// lightning:radioGroup ...), aby na nej sedelo puvodni CSS beze zmen.
import { LightningElement, api, track } from 'lwc';
import getFieldSetWrapper from '@salesforce/apex/DonationPageController.getFieldSetWrapper';
import getReferenceId from '@salesforce/apex/DonationPageController.getReferenceId';
import createComgatePayment from '@salesforce/apex/DonationPageController.createComgatePayment';
import createRelatedRecords from '@salesforce/apex/DonationPageController.createRelatedRecords';
import justCreateRecords from '@salesforce/apex/DonationPageController.justCreateRecords';
import DONATION_PAGE_IMAGES from '@salesforce/resourceUrl/DonationPageImages';
import { navigateTop, shouldRedirectToGateway } from 'c/donationEmbed';

const STEP = {
    FIRST: 'first',
    DETAILS: 'personDetails',
    METHOD: 'paymentMethodsSelection',
    GATEWAY: 'paymentMethods',
    LAST: 'last'
};

const DONATION_TYPES = [
    { label: 'Jednorázově', value: 'oneoff' },
    { label: 'Měsíčně', value: 'recurring_monthly' },
    { label: 'Ročně', value: 'recurring_yearly' }
];

const PAYMENT_OPTIONS = [
    { label: 'Platební karta', value: 'card' },
    { label: 'Platební převod', value: 'banktransfer' }
];

const ACCOUNT_TYPES = [
    { label: 'Fyzická osoba', value: 'person' },
    { label: 'Právnická osoba', value: 'legal' }
];

const FREQUENCY_ALIASES = {
    oneoff: 'oneoff',
    once: 'oneoff',
    monthly: 'recurring_monthly',
    recurring_monthly: 'recurring_monthly',
    yearly: 'recurring_yearly',
    recurring_yearly: 'recurring_yearly'
};

const MIN_AMOUNT = 15;
const REQUIRED_MESSAGE = 'Vyplňte toto pole.';

// Pole firemni vetve formulare - stejna jako v Aura sablone
const LEGAL_FIELDS = [
    { key: 'ico', target: 'donor', field: 'CRMforNonProfit__ICO__c', label: 'IČ', required: true, size: 'half-left' },
    { key: 'dic', target: 'donor', field: 'Tax_identification_number__c', label: 'DIČ', required: false, size: 'half' },
    { key: 'name', target: 'donor', field: 'Name', label: 'Firma', required: true, size: 'full' },
    { key: 'first', target: 'contact', field: 'FirstName', label: 'Jméno kontaktní osoby', required: true, size: 'half-left' },
    { key: 'last', target: 'contact', field: 'LastName', label: 'Příjmení kontaktní osoby', required: true, size: 'half' },
    { key: 'dept', target: 'contact', field: 'Department', label: 'Pozice', required: false, size: 'full' },
    { key: 'phone', target: 'contact', field: 'MobilePhone', label: 'Telefon', required: true, size: 'full', type: 'tel' },
    { key: 'email', target: 'contact', field: 'Email', label: 'E-Mail', required: true, size: 'full', type: 'email' }
];
const LEGAL_ADDRESS_FIELDS = [
    { key: 'street', target: 'donor', field: 'BillingStreet', label: 'Ulice a č. p.', required: true, size: 'street' },
    { key: 'city', target: 'donor', field: 'BillingCity', label: 'Obec', required: true, size: 'half-left' },
    { key: 'zip', target: 'donor', field: 'BillingPostalCode', label: 'PSČ', required: true, size: 'half-left' }
];

const SIZE_CLASS = {
    full: 'slds-col slds-size_1-of-1 slds-p-vertical_small',
    half: 'slds-col slds-size_1-of-2 slds-p-vertical_small',
    'half-left': 'slds-col slds-size_1-of-2 slds-p-right_small slds-p-vertical_small',
    street: 'slds-col slds-size_1-of-1 slds-p-bottom_small'
};

let uid = 0;

export default class DkdDonationForm extends LightningElement {
    static renderMode = 'light';

    // ===== nastaveni z Experience Builderu (odpovida design atributum Aura formulare) =====
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
    // auto = brana v iframe, v in-app prohlizecich (Instagram, Facebook...) v hlavnim okne kvuli 3D Secure
    @api gatewayMode = 'auto';

    // ===== stav =====
    @track donor = { sobjectType: 'Account' };
    @track contactPerson = { sobjectType: 'Contact' };
    @track paymentWrapper = { donationType: 'oneoff', donationValue: 35, paymentOption: 'card', currencyIsoCode: 'CZK' };
    @track errors = {};
    @track fieldSetWrapper = [];
    campaigns = [];
    countryOptions = [];
    bankAccountDetails = {};
    donationOptions = {};
    donationOptionSelected = '';
    currentStep = STEP.FIRST;
    donationWrapperOpened = true;
    isPersonAccount = true;
    paymentUrl;
    paymentReferenceId = '';
    thankYouText = '';
    success = false;
    spinner = false;
    spinnerMessage = 'loading';
    errorMessage = '';
    selectedCampaignId = '';
    headerLabel = '';
    inIframe = false;
    uid = 'dkd' + uid++;

    // ===== zivotni cyklus =====
    connectedCallback() {
        this.headerLabel = this.formHeaderLabel;
        this.selectedCampaignId = this.campaignId;
        const status = this.getUrlParameter('status');
        const campaignId = this.getUrlParameter('campaignId');
        const donorId = this.getUrlParameter('donorId');

        if (donorId) this.donor = { ...this.donor, Id: donorId };

        // Navrat z Comgate v iframe brany: jen ohlasime uspech rodici a nic nekreslime
        if (window.frameElement) {
            this.inIframe = true;
            window.parent.postMessage({ id: 'onSuccessPage', data: { isSuccess: true } }, '*');
            return;
        }
        if (status === 'success') {
            this.success = true;
            this.currentStep = STEP.LAST;
            this.pushPurchaseDataLayer();
            this.redirectToThankYouPage();
        }
        if (campaignId) this.selectedCampaignId = campaignId;
        if (this.selectedCampaignId) this.notifyCampaign(this.selectedCampaignId);

        this.paymentWrapper.redirectURL = window.location.protocol + '//' + window.location.host + window.location.pathname;
        this.filterAllowedPaymentMethods();
        this.filterAllowedDonationTypes();
        this.setDonationAmounts();
        this.loadFieldSets();
        this.applyUrlPrefill();

        this.messageHandler = (event) => {
            if (event.data && event.data.id === 'onSuccessPage') {
                this.success = true;
                this.currentStep = STEP.LAST;
                this.redirectToThankYouPage();
            }
        };
        window.addEventListener('message', this.messageHandler);
    }

    renderedCallback() {
        // Rich text z kampane - lwc:inner-html platforma nepodporuje, v light DOM se vlozi rucne
        const box = this.querySelector('.dkd-thank-you-text');
        if (box && box.dataset.html !== this.thankYouText) {
            box.innerHTML = this.thankYouText || '';
            box.dataset.html = this.thankYouText || '';
        }
    }

    disconnectedCallback() {
        if (this.messageHandler) window.removeEventListener('message', this.messageHandler);
    }

    // ===== nacteni ciselniku =====
    loadFieldSets() {
        this.spinner = true;
        this.spinnerMessage = 'loading';
        getFieldSetWrapper({
            fieldSetName: this.fieldSetSelection,
            donorId: this.donor.Id || null,
            campaignId: this.selectedCampaignId || null
        })
            .then((result) => {
                const body = JSON.parse(result);
                if (body.donor) this.donor = { sobjectType: 'Account', ...body.donor };
                this.fieldSetWrapper = body.fieldSetWrapper || [];
                this.campaigns = body.campaigns || [];
                this.countryOptions = body.countryOptions || [];
                if (!this.selectedCampaignId && this.campaigns.length) {
                    this.selectedCampaignId = this.campaigns[0].Id;
                    this.notifyCampaign(this.selectedCampaignId);
                }
                this.setFieldsFromSelectedCampaign(this.selectedCampaignId);
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error('loadFieldSets failed', e);
                this.errorMessage = this.getErrorMessage(e);
            })
            .finally(() => {
                this.spinner = false;
            });
    }

    filterAllowedPaymentMethods() {
        const config = { card: this.paymentCard, banktransfer: this.paymentBankTransfer };
        this.allowedPaymentOptions = PAYMENT_OPTIONS.filter((o) => config[o.value]);
        this.paymentWrapper.allowedPaymentMethods = this.allowedPaymentOptions.map((o) => o.value);
        this.paymentWrapper.paymentOption = this.defaultPaymentOption;
    }

    filterAllowedDonationTypes() {
        const config = { oneoff: this.donationTypeOneOff, recurring_monthly: this.donationTypeMonthly, recurring_yearly: this.donationTypeYearly };
        this.allowedDonationTypes = DONATION_TYPES.filter((o) => config[o.value]);
        this.paymentWrapper.donationType = this.defaultDonationType;
    }

    setDonationAmounts() {
        this.donationOptions = {
            oneoff: this.parseAmounts(this.amountsOneOff),
            recurring_monthly: this.parseAmounts(this.amountsMonthly),
            recurring_yearly: this.parseAmounts(this.amountsYearly)
        };
        this.setDefaultDonationAmount(this.defaultDonationType);
    }

    parseAmounts(selections) {
        return String(selections || '')
            .split(';')
            .filter((item) => item !== '')
            .map((item) => {
                const isOther = String(item).toLowerCase() === 'other';
                return { label: isOther ? 'Jiná' : item + ' Kč', value: isOther ? 'other' : item };
            });
    }

    setDefaultDonationAmount(type) {
        if (!type) {
            this.donationOptionSelected = '';
            this.paymentWrapper.donationValue = null;
            return;
        }
        const options = this.donationOptions[type] || [];
        let amount = null;
        if (options.length > 1) amount = options[1].value;
        else if (options.length === 1) amount = options[0].value;
        this.donationOptionSelected = amount + '';
        this.paymentWrapper.donationValue = amount;
    }

    applyUrlPrefill() {
        if (this.success) return;
        const donationType = FREQUENCY_ALIASES[String(this.getUrlParameter('frequency') || '').toLowerCase()];
        if (donationType && this.allowedDonationTypes.some((o) => o.value === donationType)) {
            this.paymentWrapper.donationType = donationType;
            this.setDefaultDonationAmount(donationType);
        }
        const urlAmount = this.getUrlParameter('amount');
        if (urlAmount !== undefined) {
            const normalized = String(urlAmount).replace(',', '.');
            const numeric = parseFloat(normalized);
            if (!isNaN(numeric) && numeric > 0) {
                const options = this.donationOptions[this.paymentWrapper.donationType] || [];
                const preset = options.find((o) => !isNaN(o.value) && parseFloat(o.value) === numeric);
                this.donationOptionSelected = preset ? preset.value + '' : 'other';
                this.paymentWrapper.donationValue = preset ? preset.value : normalized;
            }
        }
        const urlStep = this.getUrlParameter('step');
        if ((urlStep === '2' || urlStep === 'personDetails') && this.currentStep === STEP.FIRST) {
            const value = parseFloat(String(this.paymentWrapper.donationValue).replace(',', '.'));
            if (!isNaN(value) && value >= MIN_AMOUNT) this.currentStep = STEP.DETAILS;
        }
    }

    setFieldsFromSelectedCampaign(campaignId) {
        if (!campaignId) return;
        const selected = this.campaigns.find((c) => c.Id === campaignId);
        if (!selected) return;
        this.headerLabel = selected.Name;
        this.thankYouText = selected.Donation_Page_Thank_You_Text__c || '';
    }

    notifyCampaign(campaignId) {
        // Aura verze posilala zpravu pres LMS - tady stranka posloucha udalost
        this.dispatchEvent(new CustomEvent('campaignchange', { detail: { recordId: campaignId }, bubbles: true, composed: true }));
    }

    // ===== gettery pro sablonu =====
    get isFirst() { return this.currentStep === STEP.FIRST; }
    get isDetails() { return this.currentStep === STEP.DETAILS; }
    get isMethod() { return this.currentStep === STEP.METHOD; }
    get isGateway() { return this.currentStep === STEP.GATEWAY; }
    get isLast() { return this.currentStep === STEP.LAST; }
    get showSpinner() { return this.spinner; }
    get spinnerClass() { return 'dkd-form slds-spinner_container custom-spinner ' + (this.spinnerMessage || ''); }
    get containerClass() { return 'slds-grid slds-wrap form-container-1' + (this.donationWrapperOpened ? '' : ' hidden'); }
    get containerClass2() { return 'slds-grid slds-wrap form-container-2' + (this.donationWrapperOpened ? '' : ' hidden'); }
    get expanderClass() { return 'donate-button-expand slds-align_absolute-center' + (this.donationWrapperOpened ? ' expanded' : ''); }
    get openerClass() { return (this.donationWrapperOpened ? 'down' : 'up') + ' button-opener slds-align-middle slds-m-right_small'; }
    get rootStyle() { return '--dkd-icon-check: url(' + DONATION_PAGE_IMAGES + '/icons/icon-check.svg)'; }
    get showCampaignSelection() { return !this.disabledCampaignSelection; }
    get isBankTransfer() { return this.paymentWrapper.paymentOption === 'banktransfer'; }
    get hasThankYouText() { return !!this.thankYouText; }
    get hasPaymentUrl() { return !!this.paymentUrl; }
    get amountDisabled() { return this.donationOptionSelected !== 'other'; }
    get amountValue() { return this.paymentWrapper.donationValue == null ? '' : this.paymentWrapper.donationValue; }
    get amountWrapperClass() { return 'dkd-input amount-input slds-col' + (this.errors.amount ? ' slds-has-error' : ''); }
    get amountError() { return this.errors.amount; }
    get campaignSelectClass() { return 'brand-input slds-col slds-size_1-of-1 slds-p-vertical_small label-hidden' + (this.selectedCampaignId ? ' selected' : ''); }

    get donateLabel() {
        const t = this.paymentWrapper.donationType;
        const when = t === 'oneoff' ? 'jednorázově' : t === 'recurring_monthly' ? 'měsíčně' : 'ročně';
        return 'Ano, darovat ' + (this.paymentWrapper.donationValue == null ? '' : this.paymentWrapper.donationValue) + ' Kč ' + when;
    }

    radioButtons(group, options, selected) {
        return options.map((o, i) => ({
            ...o,
            key: group + '-' + i,
            id: this.uid + '-' + group + '-' + i,
            checked: String(o.value) === String(selected)
        }));
    }

    get amountOptions() {
        return this.radioButtons('amount', this.donationOptions[this.paymentWrapper.donationType] || [], this.donationOptionSelected);
    }
    get donationTypeOptions() {
        return this.radioButtons('type', this.allowedDonationTypes || [], this.paymentWrapper.donationType);
    }
    get accountTypeOptions() {
        return this.radioButtons('acc', ACCOUNT_TYPES, this.isPersonAccount ? 'person' : 'legal');
    }
    get paymentOptions() {
        return this.radioButtons('pay', this.allowedPaymentOptions || [], this.paymentWrapper.paymentOption);
    }
    get campaignOptions() {
        return this.campaigns.map((c) => ({ value: c.Id, label: c.Name, selected: c.Id === this.selectedCampaignId }));
    }

    // Polozky field setu osoby (DonationPageFormFieldSetItem)
    get personFields() {
        return (this.fieldSetWrapper || []).map((item, i) => {
            const type = item.displayType;
            const value = this.donor[item.fieldPath];
            const isText = ['text', 'tel', 'email', 'date', 'datetime', 'number'].includes(type);
            const isPicklist = type === 'picklist';
            const isBoolean = type === 'boolean';
            const isNumberLike = type === 'currency' || type === 'percent';
            const error = this.errors['fs:' + item.fieldPath];
            return {
                key: 'fs' + i,
                id: this.uid + '-fs-' + i,
                fieldPath: item.fieldPath,
                label: item.label,
                required: item.required,
                inputType: isNumberLike ? 'number' : type === 'datetime' ? 'datetime-local' : type,
                step: type === 'percent' ? '0.01' : type === 'currency' ? '1' : undefined,
                isText: isText || isNumberLike,
                isPicklist,
                isBoolean,
                value: value == null ? '' : value,
                checked: value === true,
                options: (item.picklistValues || []).map((o) => ({ ...o, selected: o.value === value })),
                error,
                wrapperClass: 'dkd-input brand-input slds-col slds-size_1-of-1 slds-p-vertical_small' + (isPicklist && value ? ' selected' : '') + (error ? ' slds-has-error' : '')
            };
        });
    }

    buildFields(defs) {
        return defs.map((d) => {
            const record = d.target === 'donor' ? this.donor : this.contactPerson;
            const errKey = d.target + ':' + d.field;
            return {
                ...d,
                id: this.uid + '-' + d.key,
                inputType: d.type || 'text',
                value: record[d.field] == null ? '' : record[d.field],
                error: this.errors[errKey],
                wrapperClass: 'dkd-input brand-input ' + SIZE_CLASS[d.size] + (this.errors[errKey] ? ' slds-has-error' : '')
            };
        });
    }
    get legalFields() { return this.buildFields(LEGAL_FIELDS); }
    get legalAddressFields() { return this.buildFields(LEGAL_ADDRESS_FIELDS); }
    get countryFieldClass() {
        return 'dkd-input brand-input slds-col slds-size_1-of-1 slds-p-vertical_small' + (this.donor.BillingCountry ? ' selected' : '') + (this.errors['donor:BillingCountry'] ? ' slds-has-error' : '');
    }
    get countryError() { return this.errors['donor:BillingCountry']; }
    get countrySelectOptions() {
        return (this.countryOptions || []).map((o) => ({ ...o, selected: o.value === this.donor.BillingCountry }));
    }

    // ===== obsluha udalosti =====
    handleAmountOption(event) {
        const value = event.currentTarget.dataset.value;
        this.donationOptionSelected = value;
        this.paymentWrapper.donationValue = isNaN(value) ? null : parseInt(value, 10);
        if (value === 'other') {
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            Promise.resolve().then(() => {
                const input = this.querySelector('.amount-input input');
                if (input) input.focus();
            });
        } else {
            this.validateAmount();
        }
    }

    handleAmountInput(event) {
        this.paymentWrapper.donationValue = event.target.value;
        if (this.errors.amount) this.validateAmount();
    }

    handleDonationType(event) {
        const value = event.currentTarget.dataset.value;
        this.paymentWrapper.donationType = value;
        this.setDefaultDonationAmount(value);
        this.errors = { ...this.errors, amount: undefined };
    }

    handleAccountType(event) {
        const value = event.currentTarget.dataset.value;
        this.isPersonAccount = value === 'person';
        this.donor = { sobjectType: 'Account' };
        this.contactPerson = { sobjectType: 'Contact' };
        this.errors = {};
    }

    handlePaymentOption(event) {
        this.paymentWrapper.paymentOption = event.currentTarget.dataset.value;
    }

    handleCampaignChange(event) {
        this.selectedCampaignId = event.target.value;
        this.notifyCampaign(this.selectedCampaignId);
        this.setFieldsFromSelectedCampaign(this.selectedCampaignId);
    }

    handleFieldSetInput(event) {
        const field = event.target.dataset.field;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value;
        this.donor = { ...this.donor, [field]: value };
        if (this.errors['fs:' + field]) this.errors = { ...this.errors, ['fs:' + field]: undefined };
    }

    handleFieldInput(event) {
        const { target, field } = event.target.dataset;
        const value = event.target.value;
        if (target === 'donor') this.donor = { ...this.donor, [field]: value };
        else this.contactPerson = { ...this.contactPerson, [field]: value };
        const key = target + ':' + field;
        if (this.errors[key]) this.errors = { ...this.errors, [key]: undefined };
    }

    handleDonationExpander() {
        this.donationWrapperOpened = !this.donationWrapperOpened;
    }

    handleStepBack() {
        this.errorMessage = '';
        if (this.currentStep === STEP.DETAILS) this.currentStep = STEP.FIRST;
        else if (this.currentStep === STEP.METHOD) this.currentStep = STEP.DETAILS;
        else if (this.currentStep === STEP.GATEWAY) {
            this.paymentUrl = null;
            this.currentStep = STEP.METHOD;
        }
    }

    handleDonate() {
        if (!this.validateForm()) return;
        this.errorMessage = '';
        if (this.currentStep === STEP.FIRST) {
            this.currentStep = STEP.DETAILS;
            this.scrollFormTop();
            return;
        }
        if (this.currentStep === STEP.DETAILS) {
            this.currentStep = STEP.METHOD;
            this.scrollFormTop();
            return;
        }
        if (this.currentStep === STEP.METHOD) {
            if (this.paymentWrapper.paymentOption === 'banktransfer') {
                this.payByBankTransfer();
                return;
            }
            this.currentStep = STEP.GATEWAY;
            this.scrollFormTop();
        }
        this.startCardPayment();
    }

    // ===== platba =====
    startCardPayment() {
        this.spinner = true;
        this.spinnerMessage = 'processing';
        const paymentWrapper = { ...this.paymentWrapper };
        if (isNaN(paymentWrapper.donationValue)) paymentWrapper.donationValue = String(paymentWrapper.donationValue).replace(',', '.');
        this.paymentWrapper = paymentWrapper;

        let shopperReference;
        let paymentReference;
        getReferenceId({
            donorString: JSON.stringify(this.donor),
            conString: JSON.stringify(this.contactPerson),
            isPersonAccount: this.isPersonAccount,
            campaignId: this.selectedCampaignId,
            paymentWrapperString: JSON.stringify(paymentWrapper)
        })
            .then((result) => {
                const body = JSON.parse(result);
                shopperReference = body.shopperReference;
                paymentReference = body.paymentReference;
                if (!this.isPersonAccount) this.donor = { ...this.donor, PersonEmail: this.contactPerson.Email };
                this.storePurchaseDataLayer(paymentReference);
                this.spinnerMessage = 'redirecting';
                return createComgatePayment({
                    paymentReferenceId: paymentReference,
                    donorString: JSON.stringify(this.donor),
                    campaignId: this.selectedCampaignId,
                    paymentWrapperString: JSON.stringify(this.paymentWrapper)
                });
            })
            .then((result) => {
                this.paymentReferenceId = paymentReference;
                createRelatedRecords({ paymentReferenceId: paymentReference, shopperReferenceId: shopperReference }).catch((e) => {
                    // eslint-disable-next-line no-console
                    console.error('createRelatedRecords failed', e);
                });
                this.pushCheckoutDataLayer(paymentReference);
                if (result == null) {
                    this.currentStep = STEP.METHOD;
                    this.spinner = false;
                    this.spinnerMessage = '';
                    this.errorMessage = 'Vytvoření platby se nezdařilo, zkuste to prosím znovu.' + (this.supportEmail ? ' Pokud problém přetrvává, kontaktujte ' + this.supportEmail + '.' : '');
                    return;
                }
                if (shouldRedirectToGateway(this.gatewayMode)) {
                    navigateTop(result);
                    return;
                }
                this.paymentUrl = result;
                // eslint-disable-next-line @lwc/lwc/no-async-operation
                window.setTimeout(() => {
                    this.spinner = false;
                    this.spinnerMessage = '';
                }, 1000);
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error(e);
                this.errorMessage = this.getErrorMessage(e);
                this.onError({ name: 'HandleDonate', message: this.errorMessage });
                this.spinner = false;
                this.spinnerMessage = '';
                this.currentStep = STEP.METHOD;
            });
    }

    payByBankTransfer() {
        this.spinner = true;
        this.spinnerMessage = 'processing';
        justCreateRecords({
            donorString: JSON.stringify(this.donor),
            conString: JSON.stringify(this.contactPerson),
            isPersonAccount: this.isPersonAccount,
            campaignId: this.selectedCampaignId,
            paymentWrapperString: JSON.stringify(this.paymentWrapper)
        })
            .then((result) => {
                this.bankAccountDetails = result || {};
                this.currentStep = STEP.LAST;
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error(e);
                this.errorMessage = this.getErrorMessage(e);
            })
            .finally(() => {
                this.spinner = false;
                this.spinnerMessage = '';
            });
        this.scrollFormTop();
    }

    // ===== validace =====
    validateAmount() {
        const raw = this.paymentWrapper.donationValue;
        const value = parseFloat(String(raw == null ? '' : raw).replace(',', '.'));
        let message;
        if (raw === null || raw === undefined || raw === '') message = REQUIRED_MESSAGE;
        else if (isNaN(value)) message = 'Zadejte platnou částku.';
        else if (value < MIN_AMOUNT) message = 'Hodnota musí být ' + MIN_AMOUNT + ' nebo vyšší.';
        this.errors = { ...this.errors, amount: message };
        return !message;
    }

    validateForm() {
        if (this.currentStep === STEP.FIRST) return this.validateAmount();
        if (this.currentStep !== STEP.DETAILS) return true;
        const errors = {};
        const isEmpty = (v) => v === undefined || v === null || String(v).trim() === '';
        const emailOk = (v) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(v).trim());
        if (this.isPersonAccount) {
            (this.fieldSetWrapper || []).forEach((item) => {
                const v = this.donor[item.fieldPath];
                if (item.required && (item.displayType === 'boolean' ? v !== true : isEmpty(v))) errors['fs:' + item.fieldPath] = REQUIRED_MESSAGE;
                else if (item.displayType === 'email' && !isEmpty(v) && !emailOk(v)) errors['fs:' + item.fieldPath] = 'Zadejte platnou e-mailovou adresu.';
            });
        } else {
            [...LEGAL_FIELDS, ...LEGAL_ADDRESS_FIELDS].forEach((d) => {
                const record = d.target === 'donor' ? this.donor : this.contactPerson;
                const v = record[d.field];
                if (d.required && isEmpty(v)) errors[d.target + ':' + d.field] = REQUIRED_MESSAGE;
                else if (d.type === 'email' && !isEmpty(v) && !emailOk(v)) errors[d.target + ':' + d.field] = 'Zadejte platnou e-mailovou adresu.';
            });
            if (isEmpty(this.donor.BillingCountry)) errors['donor:BillingCountry'] = REQUIRED_MESSAGE;
        }
        this.errors = errors;
        return Object.keys(errors).length === 0;
    }

    // ===== pomocne =====
    scrollFormTop() {
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }

    redirectToThankYouPage() {
        const url = (this.thankYouPageUrl || '').trim();
        if (!url) return false;
        // Ven z iframe platebni brany i z iframe hostitelskeho webu
        navigateTop(url);
        return true;
    }

    getUrlParameter(name) {
        const params = decodeURIComponent(window.location.search.substring(1)).split('&');
        for (let i = 0; i < params.length; i++) {
            const pair = params[i].split('=');
            if (pair[0] === name) return pair[1] === undefined ? true : pair[1];
        }
        return undefined;
    }

    getErrorMessage(e) {
        if (!e) return 'Neznámá chyba.';
        if (e.body && e.body.message) return e.body.message;
        if (Array.isArray(e) && e.length && e[0].message) return e[0].message;
        return e.message || String(e);
    }

    getPaymentFrequency(type) {
        return { recurring_monthly: 'monthly', oneoff: 'once', recurring_yearly: 'yearly' }[type] || '';
    }

    getPaymentType(option) {
        return { card: 'creditcard', paypal: 'paypal', sepadirectdebit: 'directdebit' }[option] || '';
    }

    // ===== GTM / Jentis (stejne udalosti jako Aura verze) =====
    pushCheckoutDataLayer(recordId) {
        const pw = this.paymentWrapper;
        const gtm = {
            event: 'checkout',
            ecommerce: {
                checkout: {
                    actionField: { step: this.currentStep, option: this.getPaymentType(pw.paymentOption) },
                    products: [{
                        name: window.location.pathname, id: this.getPaymentFrequency(pw.donationType), price: pw.donationValue, brand: '',
                        category: this.getPaymentType(pw.paymentOption), variant: this.getPaymentFrequency(pw.donationType), quantity: 1, coupon: ''
                    }]
                }
            }
        };
        document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: gtm } }));
        const jentis = {
            event: 'begin_checkout',
            ecommerce: {
                transaction_id: recordId, campaign_name: window.location.pathname, currency: pw.currencyIsoCode, value: pw.donationValue,
                recurrence: this.getPaymentFrequency(pw.donationType), payment_type: this.getPaymentType(pw.paymentOption),
                items: [{ item_name: window.location.pathname, currency: pw.currencyIsoCode, price: pw.donationValue, quantity: 1 }]
            }
        };
        document.dispatchEvent(new CustomEvent('user_interaction', { detail: jentis }));
    }

    storePurchaseDataLayer(recordId) {
        const pw = this.paymentWrapper;
        const product = {
            name: window.location.pathname, id: this.getPaymentFrequency(pw.donationType), category: this.getPaymentType(pw.paymentOption),
            brand: '', price: pw.donationValue, variant: this.getPaymentFrequency(pw.donationType), quantity: 1, coupon: ''
        };
        const revenue = ['recurring_monthly', 'oneoff', 'recurring_yearly'].includes(pw.donationType) ? pw.donationValue : 0;
        const events = {
            gtm: { event: 'purchase', ecommerce: { purchase: { actionField: { id: recordId, affiliation: '', revenue, tax: '', shipping: '', coupon: '' }, products: [product] } } },
            jentis: {
                event: 'Purchase',
                ecommerce: {
                    transaction_id: recordId, campaign_name: window.location.pathname, currency: pw.currencyIsoCode, value: pw.donationValue,
                    recurrence: this.getPaymentFrequency(pw.donationType), payment_type: this.getPaymentType(pw.paymentOption),
                    items: [{ item_name: window.location.pathname, currency: pw.currencyIsoCode, price: pw.donationValue, quantity: 1 }]
                }
            }
        };
        try {
            window.localStorage.setItem('dataLayerEvents', JSON.stringify(events));
        } catch (e) {
            // localStorage muze byt v iframe tretich stran blokovane
        }
    }

    pushPurchaseDataLayer() {
        let events = null;
        try {
            const raw = window.localStorage.getItem('dataLayerEvents');
            events = raw ? JSON.parse(raw) : null;
            if (events) window.localStorage.removeItem('dataLayerEvents');
        } catch (e) {
            events = null;
        }
        if (!events) return;
        document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: events.gtm } }));
        document.dispatchEvent(new CustomEvent('user_interaction', { detail: events.jentis }));
    }

    onError(error) {
        const pw = this.paymentWrapper;
        document.dispatchEvent(new CustomEvent('pushDataLayer', { detail: { event: {
            event: 'donation_error', error_code: error.name, error_message: error.message, error_stack: error.stack,
            ecommerce: { products: [{ name: window.location.pathname, id: this.getPaymentFrequency(pw.donationType), price: pw.donationValue, brand: '',
                category: this.getPaymentType(pw.paymentOption), variant: this.getPaymentFrequency(pw.donationType), quantity: 1, coupon: '' }] }
        } } }));
        document.dispatchEvent(new CustomEvent('user_interaction', { detail: {
            event: 'error', error_code: error.name, error_message: error.message, error_stack: error.stack,
            ecommerce: { transaction_id: this.paymentReferenceId, campaign_name: window.location.pathname, currency: pw.currencyIsoCode, value: pw.donationValue,
                recurrence: this.getPaymentFrequency(pw.donationType), payment_type: this.getPaymentType(pw.paymentOption),
                items: [{ item_name: window.location.pathname, currency: pw.currencyIsoCode, price: pw.donationValue, quantity: 1 }] }
        } }));
    }
}