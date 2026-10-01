# Newsletter a e-mailový builder (CRDM)

## Newsletter „Jeden klik“ (10/2026)

Předmět „Podívejte se, co se díky vám daří“, ve dvou podobách se stejným obsahem:

- **DKD Newsletter Jeden klik 10/2026 (HTML)** – klasická HTML šablona (Custom HTML) ve složce
  **DKD Newslettery**. HTML zůstává celé včetně hlavičky a stylů a upravuje se ve zdrojovém kódu
  (Setup → Classic Email Templates). Tuhle verzi používat pro rozesílku.
- **Newsletter DKD – Jeden klik (10/2026)** – Lightning šablona ve složce **Newslettery**.

- 17 obrázků je v Souborech jako `newsletter-dkd-jeden-klik-NN-*` s veřejným odkazem
  (Content Delivery). HTML na ně odkazuje přes `…/sfc/dist/version/download/…`.
  **Soubory ani jejich veřejné odkazy nemažte** – obrázky by zmizely i z už odeslaných e-mailů.
- `content/newsletter-dkd-jeden-klik-2026-10.html` – celé HTML šablony, jak je v CRM.
- `content/newsletter-dkd-jeden-klik-2026-10-builder-html-blok.html` – totéž bez hlavičky
  a s kratšími styly (8 066 znaků) pro komponentu **HTML** v drag-and-drop builderu.

### Proč šablona není rovnou v builderu

Šablonu, která se otevírá v drag-and-drop builderu, Salesforce přes API ani Metadata API
vytvořit nedovolí (`IsBuilderContent` je jen pro čtení). Šablona vytvořená přes API se
otevírá v běžném editoru. Builderová verze vznikne v aplikaci za minutu:

1. Email Templates → New Email Template → **Edit in Builder**.
2. Přetáhnout komponentu **HTML** a vložit obsah souboru `…-builder-html-blok.html`.
3. Uložit do složky Newslettery.

Limit komponenty HTML je 10 000 znaků; delší newsletter je potřeba rozdělit do více bloků.

## Přístup do builderu

Oprávnění **Access Drag-and-Drop Content Builder** nejde zapnout na standardních profilech
(System Administrator, Standard User) – Salesforce to odmítne. Je proto v sadě oprávnění
`DKD_Email_Builder`, přiřazené všem aktivním uživatelům s těmito profily.

## Odeslání z kampaně

Na rozvržení kampaně je akce **Send Email** (hromadný e-mail členům kampaně) první
v horním panelu, viz `src-crdm-layouts`.
