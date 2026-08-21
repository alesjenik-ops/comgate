import { LightningElement, api } from 'lwc';
import basePath from '@salesforce/community/basePath';
import FONTS from '@salesforce/resourceUrl/DonationPageFonts';
import LOGO from '@salesforce/resourceUrl/DonationPageHeaderLogo';

const FONT_STYLE_ID = 'dkd-community-fonts';
const FONT_FILES = [
    { weight: 400, file: 'fira-sans-v18-latin_latin-ext-regular.woff2' },
    { weight: 500, file: 'fira-sans-v18-latin_latin-ext-500.woff2' },
    { weight: 700, file: 'fira-sans-v18-latin_latin-ext-700.woff2' },
    { weight: 800, file: 'fira-sans-v18-latin_latin-ext-800.woff2' }
];

export default class DonationPageLegal extends LightningElement {
    // 'terms' = všeobecné obchodní podmínky, 'privacy' = zásady ochrany osobních údajů
    @api document = 'terms';

    logoUrl = LOGO;

    connectedCallback() {
        this.injectFonts();
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

    get isTerms() {
        return this.document !== 'privacy';
    }

    get isPrivacy() {
        return this.document === 'privacy';
    }

    get homeUrl() {
        return basePath + '/';
    }

    get privacyUrl() {
        return basePath + '/ochrana-osobnich-udaju';
    }
}
