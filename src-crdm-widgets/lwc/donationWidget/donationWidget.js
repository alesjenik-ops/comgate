import { LightningElement, api } from 'lwc';
import { injectDonationFonts } from 'c/donationFonts';
import getFieldSetWrapper from '@salesforce/apex/DonationPageController.getFieldSetWrapper';
import getReferenceId from '@salesforce/apex/DonationPageController.getReferenceId';
import createComgatePayment from '@salesforce/apex/DonationPageController.createComgatePayment';
import createRelatedRecords from '@salesforce/apex/DonationPageController.createRelatedRecords';
import justCreateRecords from '@salesforce/apex/DonationPageController.justCreateRecords';

const FIELD_SET_NAME = 'DonationPageFieldSet';
const SUPPORT_EMAIL = 'info@darujemekrouzky.cz';
const RECEIVER_NAME = 'Česká rada dětí a mládeže';
const MIN_AMOUNT = 15;

const FREQ = { ONEOFF: 'oneoff', MONTHLY: 'recurring_monthly' };

const URL_FREQUENCY_ALIASES = {
    oneoff: FREQ.ONEOFF,
    once: FREQ.ONEOFF,
    jednorazove: FREQ.ONEOFF,
    monthly: FREQ.MONTHLY,
    mesicne: FREQ.MONTHLY,
    recurring_monthly: FREQ.MONTHLY
};

const PAYMENT_OPTIONS = [
    { label: 'Platební karta', value: 'card' },
    { label: 'Platební převod', value: 'banktransfer' }
];

const SPINNER_TEXTS = {
    loading: 'Načítání…',
    processing: 'Zpracováváme…',
    redirecting: 'Přesměrováváme na platební bránu…'
};

const STEP = {
    AMOUNT: 'amount',
    DETAILS: 'details',
    PAYMENT: 'payment',
    GATEWAY: 'gateway',
    DONE: 'done'
};

function parseAmounts(raw, fallback) {
    const list = String(raw || '')
        .split(',')
        .map((x) => x.trim())
        .filter((x) => /^[0-9]+$/.test(x));
    return list.length ? list : fallback;
}

function formatCzk(value) {
    const n = Number(String(value).replace(',', '.'));
    if (isNaN(n)) return String(value);
    return n.toLocaleString('cs-CZ').replace(/ /g, ' ');
}

export default class DonationWidget extends LightningElement {
    /* ================= design-time konfigurace ================= */

    // popup = kompaktni widget do iframe/popupu, landing = varianta se sipkou vedle formulare
    @api widgetMode = 'popup';
    // Oddeluje widgety v reportech - kazda stranka svoji kampan
    @api campaignId = '';
    @api amountsOneOff = '500,1000,1500';
    @api amountsMonthly = '500,1000,1500';
    @api allowMonthly = false;
    @api defaultFrequency = 'oneoff';

    @api headline = 'Změňte život dětem jedním kliknutím';
    @api subheadline = 'Zvolte částku a proměňte ji v konkrétní podporu dětí. Vaše vybraná částka zajistí pro děti toto:';

    // Sipka: zapnuti + varianta pro kazdy slot castky
    @api showArrow = false;
    @api arrowVariant1 = '';
    @api arrowVariant2 = '';
    @api arrowVariant3 = '';
    @api arrowVariantCustom = '';

    // Prazdna hodnota nechá darce na formulari a zobrazi podekovani primo v nem
    @api thankYouPageUrl = '';

    /* ================= stav ================= */

    step = STEP.AMOUNT;
    spinner = false;
    spinnerMessage = 'loading';
    errorMessage = '';
    amountError = '';

    campaigns = [];
    countryOptions = [];
    thankYouText = '';

    isPersonAccount = true;
    donor = { sobjectType: 'Account' };
    contactPerson = { sobjectType: 'Contact' };

    selectedAmount = '';
    customAmount = '';
    isCustomSelected = false;

    paymentWrapper = {
        donationType: FREQ.ONEOFF,
        donationValue: null,
        paymentOption: 'card',
        currencyIsoCode: 'CZK',
        allowedPaymentMethods: PAYMENT_OPTIONS.map((o) => o.value)
    };
    paymentUrl = null;
    paymentReferenceId = '';
    bankAccountDetails = {};

    /* ================= lifecycle ================= */

    connectedCallback() {
        injectDonationFonts();
        // Uvnitr iframe platebni brany jen ohlasime uspech rodicovskemu oknu
        if (window.frameElement) {
            parent.postMessage({ id: 'onSuccessPage', data: { isSuccess: true } }, '*');
            return;
        }

        const status = this.getUrlParameter('status');
        const urlCampaignId = this.getUrlParameter('campaignId');
        const urlFrequency = this.getUrlParameter('frequency');
        const urlAmount = this.getUrlParameter('amount');
        const donorId = this.getUrlParameter('donorId');

        if (donorId) this.donor = { ...this.donor, Id: donorId };
        if (urlCampaignId) this.campaignId = urlCampaignId;

        const freq = URL_FREQUENCY_ALIASES[String(urlFrequency || this.defaultFrequency).toLowerCase()];
        this.paymentWrapper = {
            ...this.paymentWrapper,
            donationType: freq === FREQ.MONTHLY && this.allowMonthly ? FREQ.MONTHLY : FREQ.ONEOFF,
            redirectURL: location.protocol + '//' + location.host + location.pathname
        };

        if (status === 'success') {
            this.step = STEP.DONE;
            if (!this.redirectToThankYouPage()) {
                this.loadFieldSets();
            }
            return;
        }

        this.applyDefaultAmount(urlAmount);
        this.loadFieldSets();
    }

    /* ================= nacteni ciselniku ================= */

    loadFieldSets() {
        this.spinner = true;
        this.spinnerMessage = 'loading';
        getFieldSetWrapper({
            fieldSetName: FIELD_SET_NAME,
            donorId: this.donor.Id || null,
            campaignId: this.campaignId || null
        })
            .then((result) => {
                const body = JSON.parse(result);
                if (body.donor) this.donor = { sobjectType: 'Account', ...body.donor };
                this.campaigns = body.campaigns || [];
                this.countryOptions = body.countryOptions || [];
                if (!this.campaignId && this.campaigns.length) this.campaignId = this.campaigns[0].Id;
                const selected = this.campaigns.find((c) => c.Id === this.campaignId);
                if (selected) this.thankYouText = selected.Donation_Page_Thank_You_Text__c || '';
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error('loadFieldSets failed', e);
            })
            .finally(() => {
                this.spinner = false;
            });
    }

    /* ================= castky ================= */

    get activeAmounts() {
        return this.isMonthly
            ? parseAmounts(this.amountsMonthly, ['500', '1000', '1500'])
            : parseAmounts(this.amountsOneOff, ['500', '1000', '1500']);
    }

    applyDefaultAmount(urlAmount) {
        const amounts = this.activeAmounts;
        const fromUrl = String(urlAmount || '').replace(/\s/g, '');
        if (/^[1-9][0-9]*$/.test(fromUrl)) {
            if (amounts.includes(fromUrl)) {
                this.selectAmount(fromUrl);
            } else {
                this.isCustomSelected = true;
                this.customAmount = fromUrl;
                this.selectedAmount = '';
                this.paymentWrapper = { ...this.paymentWrapper, donationValue: fromUrl };
            }
            return;
        }
        // Vychozi je prostredni nabidka, jako v navrhu
        this.selectAmount(amounts[1] || amounts[0]);
    }

    selectAmount(value) {
        this.selectedAmount = String(value);
        this.isCustomSelected = false;
        this.customAmount = '';
        this.amountError = '';
        this.paymentWrapper = { ...this.paymentWrapper, donationValue: String(value) };
    }

    get amountOptions() {
        return this.activeAmounts.map((value, index) => ({
            key: `a${index}`,
            value,
            label: `${formatCzk(value)} Kč`,
            slot: index,
            cssClass: !this.isCustomSelected && this.selectedAmount === value ? 'chip chip--on' : 'chip'
        }));
    }

    get customChipClass() {
        return this.isCustomSelected ? 'chip chip--on' : 'chip';
    }

    handleAmountClick(event) {
        this.selectAmount(event.currentTarget.dataset.value);
    }

    handleCustomClick() {
        this.isCustomSelected = true;
        this.selectedAmount = '';
        this.paymentWrapper = { ...this.paymentWrapper, donationValue: this.customAmount || null };
        // Po prepnuti na vlastni castku rovnou kurzor do pole
        Promise.resolve().then(() => {
            const el = this.template.querySelector('.custom-input');
            if (el) el.focus();
        });
    }

    handleCustomInput(event) {
        this.customAmount = event.target.value;
        this.amountError = '';
        this.paymentWrapper = { ...this.paymentWrapper, donationValue: event.target.value };
    }

    handleFrequencyChange(event) {
        const value = event.currentTarget.dataset.value;
        if (value === FREQ.MONTHLY && !this.allowMonthly) return;
        this.paymentWrapper = { ...this.paymentWrapper, donationType: value };
        // Sady castek se mezi frekvencemi lisi, takze vyber prepocitame
        if (!this.isCustomSelected) {
            const amounts = this.activeAmounts;
            this.selectAmount(amounts.includes(this.selectedAmount) ? this.selectedAmount : amounts[1] || amounts[0]);
        }
    }

    /* ================= sipka ================= */

    get arrowVariant() {
        if (!this.showArrow) return '';
        if (this.isCustomSelected) return this.arrowVariantCustom;
        const index = this.activeAmounts.indexOf(this.selectedAmount);
        return [this.arrowVariant1, this.arrowVariant2, this.arrowVariant3][index] || '';
    }

    get showArrowBlock() {
        return this.showArrow && !!this.arrowVariant;
    }

    /* ================= gettery: kroky a popisky ================= */

    get isLanding() {
        return this.widgetMode === 'landing';
    }
    get rootClass() {
        return this.isLanding ? 'widget widget--landing' : 'widget widget--popup';
    }
    get isStepAmount() {
        return this.step === STEP.AMOUNT;
    }
    get isStepDetails() {
        return this.step === STEP.DETAILS;
    }
    get isStepPayment() {
        return this.step === STEP.PAYMENT;
    }
    get isStepGateway() {
        return this.step === STEP.GATEWAY;
    }
    get isStepDone() {
        return this.step === STEP.DONE;
    }
    get isMonthly() {
        return this.paymentWrapper.donationType === FREQ.MONTHLY;
    }
    get isBankTransfer() {
        return this.paymentWrapper.paymentOption === 'banktransfer';
    }
    get spinnerText() {
        return SPINNER_TEXTS[this.spinnerMessage] || '';
    }
    get supportEmail() {
        return SUPPORT_EMAIL;
    }
    get receiverName() {
        return RECEIVER_NAME;
    }

    get oneOffChipClass() {
        return this.isMonthly ? 'toggle' : 'toggle toggle--on';
    }
    get monthlyChipClass() {
        return this.isMonthly ? 'toggle toggle--on' : 'toggle';
    }

    get currentAmountValue() {
        const raw = this.paymentWrapper.donationValue;
        return raw == null || raw === '' ? '' : formatCzk(raw);
    }

    get frequencyWord() {
        return this.isMonthly ? 'měsíčně' : 'jednorázově';
    }

    // "Ano, darovat 1 500 Kč měsíčně" - cifra i frekvence se meni s vyberem
    get ctaLabel() {
        const amount = this.currentAmountValue;
        if (!amount) return 'Ano, darovat';
        return `Ano, darovat ${amount} Kč ${this.frequencyWord}`;
    }

    get detailsIntro() {
        const amount = this.currentAmountValue;
        return amount ? `${amount} Kč ${this.frequencyWord}` : '';
    }

    get personTypeOptions() {
        return [
            { key: 'person', value: 'person', label: 'Fyzická osoba', cssClass: this.isPersonAccount ? 'toggle toggle--on' : 'toggle' },
            { key: 'legal', value: 'legal', label: 'Právnická osoba', cssClass: this.isPersonAccount ? 'toggle' : 'toggle toggle--on' }
        ];
    }

    get paymentOptions() {
        return PAYMENT_OPTIONS.map((o) => ({
            ...o,
            key: o.value,
            cssClass: this.paymentWrapper.paymentOption === o.value ? 'toggle toggle--on' : 'toggle'
        }));
    }

    get countryOptionList() {
        return (this.countryOptions || []).map((o, i) => ({
            key: `c${i}`,
            label: o.label || o,
            value: o.value || o
        }));
    }

    /* ================= formular ================= */

    handlePersonTypeChange(event) {
        this.isPersonAccount = event.currentTarget.dataset.value === 'person';
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

    handlePaymentOptionChange(event) {
        this.paymentWrapper = { ...this.paymentWrapper, paymentOption: event.currentTarget.dataset.value };
    }

    validate() {
        if (this.step === STEP.AMOUNT) {
            const raw = String(this.paymentWrapper.donationValue == null ? '' : this.paymentWrapper.donationValue).trim();
            const pattern = /^([1-9][0-9]*)((,|\.)([0-9]{0,7}))?$/;
            const numeric = parseFloat(raw.replace(',', '.'));
            if (!pattern.test(raw) || isNaN(numeric) || numeric < MIN_AMOUNT) {
                this.amountError = `Zadejte prosím částku alespoň ${MIN_AMOUNT} Kč.`;
                return false;
            }
            this.amountError = '';
            return true;
        }

        if (this.step === STEP.DETAILS) {
            let valid = true;
            this.template.querySelectorAll('.f-input').forEach((el) => {
                const value = (el.value || '').trim();
                let ok = true;
                if (!el.dataset.optional && !value) ok = false;
                if (value && el.type === 'email' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) ok = false;
                el.classList.toggle('invalid', !ok);
                if (!ok) valid = false;
            });
            this.errorMessage = valid ? '' : 'Vyplňte prosím všechna povinná pole.';
            return valid;
        }

        return true;
    }

    /* ================= hlavni tok ================= */

    handleNext() {
        if (!this.validate()) return;
        this.errorMessage = '';

        if (this.step === STEP.AMOUNT) {
            this.step = STEP.DETAILS;
            this.scrollTop();
            return;
        }
        if (this.step === STEP.DETAILS) {
            this.step = STEP.PAYMENT;
            this.scrollTop();
            return;
        }
        if (this.step === STEP.PAYMENT) {
            if (this.isBankTransfer) {
                this.payByBankTransfer();
                return;
            }
            this.step = STEP.GATEWAY;
            this.scrollTop();
        }

        this.startCardPayment();
    }

    startCardPayment() {
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
                const body = JSON.parse(result);
                shopperReference = body.shopperReference;
                paymentReference = body.paymentReference;
                if (!this.isPersonAccount) {
                    this.donor = { ...this.donor, PersonEmail: this.contactPerson.Email };
                }
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
                createRelatedRecords({ paymentReferenceId: paymentReference, shopperReferenceId: shopperReference }).catch((e) => {
                    // eslint-disable-next-line no-console
                    console.error('createRelatedRecords failed', e);
                });

                if (result == null) {
                    this.step = STEP.PAYMENT;
                    this.spinner = false;
                    this.spinnerMessage = '';
                    this.errorMessage =
                        'Vytvoření platby se nezdařilo, zkuste to prosím znovu. Pokud problém přetrvává, kontaktujte ' + SUPPORT_EMAIL + '.';
                    return;
                }

                this.paymentUrl = result;
                window.setTimeout(() => {
                    this.spinner = false;
                    this.spinnerMessage = '';
                }, 1000);
            })
            .catch((e) => {
                // eslint-disable-next-line no-console
                console.error(e);
                this.errorMessage = this.getErrorMessage(e);
                this.spinner = false;
                this.spinnerMessage = '';
                this.step = STEP.PAYMENT;
            });
    }

    payByBankTransfer() {
        this.spinner = true;
        this.spinnerMessage = 'processing';
        justCreateRecords({
            donorString: JSON.stringify(this.donor),
            conString: JSON.stringify(this.contactPerson),
            isPersonAccount: this.isPersonAccount,
            campaignId: this.campaignId,
            paymentWrapperString: JSON.stringify(this.paymentWrapper)
        })
            .then((result) => {
                this.bankAccountDetails = result;
                this.step = STEP.DONE;
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
    }

    handleBack() {
        this.errorMessage = '';
        if (this.step === STEP.DETAILS) this.step = STEP.AMOUNT;
        else if (this.step === STEP.PAYMENT) this.step = STEP.DETAILS;
        else if (this.step === STEP.GATEWAY) {
            this.paymentUrl = null;
            this.step = STEP.PAYMENT;
        }
    }

    /* ================= podekovani ================= */

    // Vraci true, kdyz se opravdu presmerovava - volajici pak nemusi stavet krok podekovani
    redirectToThankYouPage() {
        const url = (this.thankYouPageUrl || '').trim();
        if (!url) return false;
        try {
            // Ven z iframe platebni brany, jinak by se prekreslil jen jeho obsah
            window.top.location.href = url;
        } catch (error) {
            window.location.href = url;
        }
        return true;
    }

    /* ================= pomocne ================= */

    getErrorMessage(e) {
        if (!e) return 'Došlo k neočekávané chybě.';
        if (e.body && e.body.message) return e.body.message;
        if (e.message) return e.message;
        return 'Došlo k neočekávané chybě.';
    }

    getUrlParameter(name) {
        const params = new URLSearchParams(window.location.search);
        return params.get(name);
    }

    scrollTop() {
        const el = this.template.querySelector('.card');
        if (el && el.scrollIntoView) el.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    }
}
