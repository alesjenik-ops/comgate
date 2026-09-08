# Darcovske widgety CRDM

Nova sada darcovskych formularu pro CRDM podle navrhu z Figmy (CRDM-DEVS) a zadani
Ondreje Sejtky z 4. 9. 2026. Nasazuje se jako **unmanaged metadata primo do CRDM orgu**
(subscriber org), nema nic spolecneho s balickem `npc_bridge`.

## Co je uvnitr

| Komponenta | Ucel |
| --- | --- |
| `donationWidget` | Konfigurovatelny darcovsky formular. Jedna komponenta obsluhuje vsechny tri widgety ze zadani, lisi se jen nastavenim na strance. |
| `donationArrow` | Barevny sipkovy pruh s ikonou a textem, ktery se meni podle zvolene castky. |
| `donationThankYou` | Dekovaci sekce po uspesne platbe, obsah prevzaty z darujemekrouzky.cz/dekujeme/. |
| `DonationWidgetIcons` | Static resource se 14 line-art ikonami pro sipky (export z Figmy). |

## Stranky v community

Site `Donation_Page1` bezi na `https://darci.darujemekrouzky.cz/s/`.

| Stranka | URL | Widget ze zadani |
| --- | --- | --- |
| `widgetPopup` | `/s/widget-popup` | Widget 1 - popup na webu a na mobilu, castky 500/1000/1500 |
| `widgetLanding` | `/s/widget-landing` | Widget 2 - landing page, castky 300/1500/3000, se sipkou |
| `widgetDarci` | `/s/widget-darci` | Widget 3 - darci.darujemekrouzky.cz, castky 500/1000/1500 |
| `dekujeme` | `/s/dekujeme` | Dekovaci stranka, kam Comgate presmeruje po zaplaceni |

## Odliseni v reportech

Widgety se v reportech rozlisuji **kampani**. Vsechny tri stranky maji zatim
nastavenou stejnou kampan `701Te00000gDlc7IAC` (Darujeme krouzky detem) - je potreba
kazde priradit vlastni. Meni se v Experience Builderu ve vlastnosti *ID kampane*,
bez nasazovani.

## Sipky

Varianta sipky se voli pro kazdou castku zvlast (vlastnosti *Sipka pro 1./2./3. castku*
a *Sipka pro vlastni castku*). Katalog variant je v `donationArrow.js` v poli
`ARROW_VARIANTS` - kazda polozka nese text, barvu i ikonu. Pridani nove varianty
znamena pridat radek do pole a doplnit stejny klic do `datasource` v
`donationWidget.js-meta.xml`.

## Nasazeni

```bash
sf project deploy start --metadata-dir src-crdm-widgets --target-org <alias>
```

Stranky v community se nasazuji zvlast pres `src-site-crdm` a **je nutne pouzit
`--ignore-warnings`** - bundle obsahuje natvrdo zapsana ID kampani (i v puvodnich
strankach), ktera Salesforce jinak eskaluje na chybu:

```bash
sf project deploy start --metadata-dir src-site-crdm --target-org <alias> --ignore-warnings
```

Po nasazeni stranek je treba **site publikovat**, jinak se navstevnikum neukazou.
