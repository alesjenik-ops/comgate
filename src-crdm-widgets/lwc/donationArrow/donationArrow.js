import { LightningElement, api } from 'lwc';
import ICONS from '@salesforce/resourceUrl/DonationWidgetIcons';

// Barvy sipek podle design systemu CRDM (Figma CRDM-DEVS)
const COLORS = {
    turquoise: '#2FBAD0',
    pink: '#EC8BB6',
    purple: '#AE8FDA',
    violet: '#8F95DA'
};

// Katalog variant. Klic je to, co se uklada v konfiguraci stranky,
// label je to, co vidi admin v Experience Builderu.
export const ARROW_VARIANTS = [
    { key: 'Zadna sipka', icon: null, color: null, text: '' },
    { key: '1 dite / 1 mesic', icon: 'child-singing', color: 'turquoise', text: 'Kompletní podpora\npro 1 dítě na 1 měsíc' },
    { key: '1 dite / 1 mesic (Podpora)', icon: 'child-singing', color: 'turquoise', text: 'Podpora pro 1 dítě\nna 1 měsíc' },
    { key: '1 dite / pololeti', icon: 'child-painting', color: 'pink', text: 'Kompletní podpora\npro 1 dítě na pololetí' },
    { key: '1 dite / skolni rok', icon: 'child-jumping', color: 'purple', text: 'Kompletní podpora\npro 1 dítě na školní rok' },
    { key: '1 dite / cely rok', icon: 'child-jumping', color: 'purple', text: 'Kompletní podpora\npro 1 dítě na celý rok' },
    { key: '3 deti / pololeti', icon: 'child-heart', color: 'turquoise', text: 'Kompletní podpora\n3 dětí na pololetí' },
    { key: '6 deti / pololeti', icon: 'child-star', color: 'pink', text: 'Kompletní podpora\n6 dětí na pololetí' },
    { key: '12 deti / pololeti', icon: 'kids-three', color: 'purple', text: 'Kompletní podpora\n12 dětí na pololetí' },
    { key: '1 dite / krouzek', icon: 'child-football', color: 'pink', text: 'Podpora pro 1 dítě\nna kroužek' },
    { key: 'Oddil ci tabor (noty)', icon: 'notes', color: 'turquoise', text: 'Kompletní podpora pro 1 dítě\nna pololetí na oddíl či tábor' },
    { key: 'Oddil ci tabor (mic)', icon: 'ball', color: 'pink', text: 'Kompletní podpora pro 1 dítě\nna pololetí na oddíl či tábor' },
    { key: 'Oddil ci tabor (paleta)', icon: 'palette', color: 'purple', text: 'Kompletní podpora pro 1 dítě\nna pololetí na oddíl či tábor' },
    { key: 'Oddil ci tabor (stan)', icon: 'tent', color: 'violet', text: 'Kompletní podpora pro 1 dítě\nna pololetí na oddíl či tábor' },
    { key: 'Vlastni castka', icon: 'kids-two', color: 'violet', text: 'Podpora dětí dle vámi\nzvolené částky' },
    { key: 'Volna varianta (cteni)', icon: 'child-reading', color: 'violet', text: 'Podpora dětí dle vámi\nzvolené částky' },
    { key: 'Volna varianta (psani)', icon: 'child-writing', color: 'turquoise', text: 'Podpora dětí dle vámi\nzvolené částky' }
];

const BY_KEY = ARROW_VARIANTS.reduce((acc, v) => {
    acc[v.key] = v;
    return acc;
}, {});

export function arrowVariantKeys() {
    return ARROW_VARIANTS.map((v) => v.key);
}

export default class DonationArrow extends LightningElement {
    // Klic z katalogu. Kdyz nesedi na nic znameho, sipka se nevykresli.
    @api variant;
    // Prebiji text z katalogu, kdyz chce klient jednorazovou vyjimku
    @api overrideText;

    get resolved() {
        return BY_KEY[this.variant] || null;
    }

    get hasVariant() {
        const v = this.resolved;
        return v !== null && !!v.icon;
    }

    get iconUrl() {
        const v = this.resolved;
        return v ? `${ICONS}/icons/${v.icon}.svg` : '';
    }

    get backgroundStyle() {
        const v = this.resolved;
        return v ? `background-color: ${COLORS[v.color] || COLORS.violet};` : '';
    }

    // Text drzi zalomeni z katalogu, aby sipka vypadala jako v navrhu
    get lines() {
        const v = this.resolved;
        const raw = (this.overrideText || (v && v.text) || '').split('\n');
        return raw.map((text, i) => ({ key: `l${i}`, text }));
    }
}
