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
| `donationGateway` | Responzivni iframe Comgate (`allow="payment"`). Sdilena `comgatePaymentForm` ma iframe napevno 504 px posunuty o -250 px, v karte na mobilu pretekal. |
| `DonationWidgetIcons` | Static resource se 14 line-art ikonami pro sipky (export z Figmy). |
| `donationFonts` | Sdileny modul, ktery do stranky vstrikne `@font-face` pro Fira Sans a Source Sans 3. Volaji ho `donationWidget` i `donationThankYou`, protoze theme site fonty nenacita. |
| `DonationPageFonts` | Static resource s fonty: Fira Sans 400/500/700/800 (puvodni) + Source Sans 3 400/500/600/700 (doplneno), vzdy latin + latin-ext woff2. |

## Stranky v community

Site `Donation_Page1` bezi na `https://darci.darujemekrouzky.cz/s/`.

| Stranka | URL | Widget ze zadani |
| --- | --- | --- |
| `widgetPopup` | `/s/widget-popup` | Widget 1 - popup na webu a na mobilu, castky 500/1000/1500 |
| `widgetLanding` | `/s/widget-landing` | Widget 2 - landing page, castky 300/1500/3000, se sipkou |
| `widgetDarci` | `/s/widget-darci` | Widget 3 - darci.darujemekrouzky.cz, castky 500/1000/1500 |
| `dekujeme` | `/s/dekujeme` | Dekovaci stranka, kam Comgate presmeruje po zaplaceni |
| `widgetKrouzekLanding` | `/s/widget-krouzek-landing` | Widget 3 (desktop) - personalizovany podle `?krouzek=` |
| `widgetKrouzekPopup` | `/s/widget-krouzek-popup` | Widget 3 (mobil) - personalizovany podle `?krouzek=` |

## Odliseni v reportech

Widgety se v reportech rozlisuji **kampani**. Vsechny tri stranky maji zatim
nastavenou stejnou kampan `701Te00000gDlc7IAC` (Darujeme krouzky detem) - je potreba
kazde priradit vlastni. Meni se v Experience Builderu ve vlastnosti *ID kampane*,
bez nasazovani.

## Parametry v URL a jejich predani na dekovaci stranku

Widget si pri nacteni zapamatuje **vsechny parametry ze sve URL** (krome `status`, `id`
a `refId`, ktere pridava Comgate) a po uspesne platbe je **prida k URL dekovaci stranky**
spolu s `amount` (skutecna castka) a `frequency` (`oneoff` / `monthly`). Parametry,
ktere uz dekovaci URL obsahuje (napr. `?widget=landing`), zustavaji.

Priklad: `/s/widget-landing?campaignId=jedenklik-landing-desktop&utm_source=fb`
-> po zaplaceni `https://www.darujemekrouzky.cz/dekujeme/?widget=landing&campaignId=jedenklik-landing-desktop&utm_source=fb&amount=1500&frequency=oneoff`.

Ty same parametry se ukladaji i do `Payment_Reference__c.JSON_Payment_Wrapper__c`
(pole `source`), takze se daji dohledat i v CRM.

`campaignId` v URL prebiji kampan ze stranky **jen kdyz je to skutecne Salesforce ID**
(15/18 znaku). Jina hodnota (`jedenklik-landing-desktop`) je jen znacka zdroje: kampan
zustane ta ze stranky a hodnota jde dal na dekovaci stranku. Drive takova hodnota
rozbila nacteni kampane a dar zustal bez kampane.

Widget take **posloucha zpravu `onSuccessPage`** z iframe platebni brany (posila ji
stranka nactena v iframe po navratu z Comgate) a teprve na ni presmeruje hlavni okno na
dekovaci stranku. Bez toho darce po zaplaceni zustal koukat do prazdneho iframe.

## Personalizace podle krouzku (widget 3)

Vlastnost *Personalizovat podle parametru v URL* zapne cteni parametru `?krouzek=`.
Varianty jsou ve vlastnosti *Varianty krouzku* ve tvaru
`hodnota=text ve 4. pade|ikona;...`, vychozi:

| `?krouzek=` | Text za `{krouzek}` | Ikona sipky |
| --- | --- | --- |
| `hudba` | hudební kroužek | noty (tyrkysova) |
| `sport` | sportovní kroužek | mic (ruzova) |
| `umeni` | výtvarný kroužek | paleta (fialova) |
| `oddil` | oddíl | stan (modrofialova) |
| `tabor` | tábor | stan (modrofialova) |

Kdyz parametr sedi na variantu, widget pouzije *Personalizovany nadpis / podnadpis*
(landing) nebo *Personalizovany text pod tlacitky* (popup), v obou `{krouzek}` nahradi
textem varianty, a misto sipek podle castky ukaze jednu sipku s ikonou varianty
(texty sipek "Kompletni podpora pro 1 dite na pololeti na oddil ci tabor" z Figmy).
Bez parametru nebo s neznamou hodnotou se widget chova jako obycejny.

Text v sipce personalizovaneho widgetu je vlastnost *Personalizovany text sipky*
(vychozi `Kompletní podpora pro 1 dítě\nna pololetí na {krouzek}`), `{krouzek}` se nahradi
textem varianty a `\n` zalomi radek. Diky tomu sipka nerika u vsech variant "na oddil ci tabor",
ale "na hudební kroužek", "na výtvarný kroužek" atd. Prazdna vlastnost = text z katalogu sipek.

Sipka se v rezimu popup vykresluje pod tlacitkem - to je ten "barevny pruh dole" z
mobilni verze navrhu. Na strance `widgetKrouzekPopup` je proto *Zobrazit sipku* zapnute
a vsechny sipky podle castky nastavene na *Zadna sipka*, aby se bez parametru nic neukazalo.

## Predvyplnena zeme

Pole *Zeme* je predvyplnene hodnotou z vlastnosti *Vychozi zeme* (`Czech Republic`, musi to
byt hodnota z ciselniku `Account.Country__c`, ze ktereho Apex nabidku plni) a darci se ukaze
jako *Popisek vychozi zeme* (`Česká republika`). Ulozena hodnota zustava `Czech Republic`.
Plati pro fyzickou osobu (`PersonMailingCountry`) i firmu (`BillingCountry`) - firemni
vetev formulare dostala pole Zeme nove, drive zemi vubec nesbirala.

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
