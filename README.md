# Comgate – Salesforce metadata

Salesforce metadata projektu (retrieve z orgů, Metadata API formát). Repozitář obsahuje dvě samostatné sady metadat ze dvou různých orgů/verzí řešení:

## Struktura

- `src/` – varianta **Stripe + Nonprofit Cloud** (`CRMforNonProfit`, donor = Account): Apex třídy Stripe integrace, LWC, Visualforce, objekty, flows, statické resources, Experience Cloud site, `src/package.xml`.
- `src-comgate/` – varianta **Comgate + NPSP** (`npe03`, donor = Contact): Apex třídy Comgate integrace (ComgateService, ComgateWebhook…), Communities/Site controllery, aura komponenty, LWC, objectTranslations, `src-comgate/package.xml`.

Sady se v ~100 souborech překrývají s odlišným obsahem (např. `DonationPageController`), proto jsou drženy odděleně a nelze je slepě sloučit.

## Nasazení

Nasazení do orgu přes Salesforce CLI (vyberte příslušnou složku):

```bash
sf project deploy start --metadata-dir src --target-org <alias-orgu>
sf project deploy start --metadata-dir src-comgate --target-org <alias-orgu>
```

Případně validace bez nasazení:

```bash
sf project deploy validate --metadata-dir <složka> --target-org <alias-orgu>
```
