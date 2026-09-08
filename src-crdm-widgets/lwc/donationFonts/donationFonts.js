import FONTS from '@salesforce/resourceUrl/DonationPageFonts';

// Fonty z design systemu CRDM: Fira Sans na nadpisy a tlacitka, Source Sans 3 na text.
// Soubory lezi ve static resource DonationPageFonts (latin + latin-ext).
const STYLE_ID = 'crdm-donation-fonts';
const FACES = [
    { family: 'Fira Sans', weight: 400, file: 'fira-sans-v18-latin_latin-ext-regular.woff2' },
    { family: 'Fira Sans', weight: 500, file: 'fira-sans-v18-latin_latin-ext-500.woff2' },
    { family: 'Fira Sans', weight: 700, file: 'fira-sans-v18-latin_latin-ext-700.woff2' },
    { family: 'Fira Sans', weight: 800, file: 'fira-sans-v18-latin_latin-ext-800.woff2' },
    { family: 'Source Sans 3', weight: 400, file: 'source-sans-3-v19-latin_latin-ext-regular.woff2' },
    { family: 'Source Sans 3', weight: 500, file: 'source-sans-3-v19-latin_latin-ext-500.woff2' },
    { family: 'Source Sans 3', weight: 600, file: 'source-sans-3-v19-latin_latin-ext-600.woff2' },
    { family: 'Source Sans 3', weight: 700, file: 'source-sans-3-v19-latin_latin-ext-700.woff2' }
];

// Vstrikne @font-face do <head> jednou za stranku; dalsi volani jsou no-op.
export function injectDonationFonts() {
    if (typeof document === 'undefined' || document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = FACES.map(
        (f) =>
            `@font-face{font-family:'${f.family}';font-style:normal;font-weight:${f.weight};` +
            `font-display:swap;src:url('${FONTS}/${f.file}') format('woff2')}`
    ).join('\n');
    document.head.appendChild(style);
}
