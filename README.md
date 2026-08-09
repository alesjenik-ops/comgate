# Comgate – Salesforce metadata

Salesforce metadata projektu (retrieve z orgu, Metadata API formát).

## Struktura

- `src/` – kompletní metadata včetně `src/package.xml` (Apex třídy, LWC, Visualforce stránky, objekty, flows, statické resources, Experience Cloud site atd.)

## Nasazení

Nasazení do orgu přes Salesforce CLI:

```bash
sf project deploy start --metadata-dir src --target-org <alias-orgu>
```

Případně validace bez nasazení:

```bash
sf project deploy validate --metadata-dir src --target-org <alias-orgu>
```
