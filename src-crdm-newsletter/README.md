# Newsletter a e-mailový builder (CRDM)

## Newsletter „Jeden klik“ (10/2026)

Jediná šablona: Lightning **Newsletter DKD – Jeden klik (10/2026)** ve složce **Newslettery**
(veřejná), předmět „Podívejte se, co se díky vám daří“. Klasická HTML kopie byla 1. 10. 2026
smazána, aby existovala jen jedna verze.

- Texty jsou **HTML s CSS**, ne obrázky. Obrázky jsou jen čtyři: logo, koláž fotek kampaně,
  mapa krajů a koláč aktivit (legenda je text). Rozvržení je tabulkové s inline styly
  (Outlook, Gmail), šířka 640 px, na mobilu se sloupce skládají pod sebe. Písmo Fira Sans,
  kde ho klient nemá, Segoe UI / Arial.
- Obrázky jsou v Souborech jako `newsletter-dkd-jeden-klik-*` s veřejným odkazem
  (Content Delivery), HTML na ně odkazuje přes `…/sfc/dist/version/download/…`.
  **Soubory ani jejich veřejné odkazy nemažte** – obrázky by zmizely i z už odeslaných e-mailů.
- `content/newsletter-dkd-jeden-klik-2026-10.html` – HTML šablony, jak je v CRM;
  `content/build_newsletter_html.py` ho generuje (texty, barvy, odkazy).
- HTML je do šablony nahrané přes API. **Uložení šablony v Lightning editoru ho může
  přepsat** (styly pro mobil, odkaz na písmo) – změny dělat ve skriptu a nahrát znovu.

### Drag-and-drop builder

Šablonu, která se otevírá v builderu, Salesforce přes API ani Metadata API vytvořit
nedovolí (`IsBuilderContent` je jen pro čtení). Builderová verze se dá udělat ručně:
New Email Template → Edit in Builder → komponenta **HTML** (limit 10 000 znaků na komponentu).

## Přístup do builderu

Oprávnění **Access Drag-and-Drop Content Builder** nejde zapnout na standardních profilech
(System Administrator, Standard User) – Salesforce to odmítne. Je proto v sadě oprávnění
`DKD_Email_Builder`, přiřazené všem aktivním uživatelům s těmito profily.

## Odeslání z kampaně

Na rozvržení kampaně je akce **Send Email** (hromadný e-mail členům kampaně) první
v horním panelu, viz `src-crdm-layouts`.
