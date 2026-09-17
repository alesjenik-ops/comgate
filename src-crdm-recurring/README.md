# Pravidelné dary – zpracování závazků (CRDM)

Denní úloha, bez které se z pravidelného daru vybere jen první splátka.

## Proč to tu je

Darovací formulář zakládá `GiftCommitment`, `GiftCommitmentSchedule` i první
`GiftTransaction` obyčejným zápisem do databáze (viz `DonationPageController`).
Kalendář ale nenaváže na závazek – `CurrentGiftCmtScheduleId` zůstane prázdné,
stejně jako `NextTransactionDate`. Salesforce pak závazek nepovažuje za svůj a
**žádnou další splátku nezaloží**. Dávka Comgate (`ComgateChargePaymentsBatch`)
strhává jen splátky, které už v CRM leží, takže by dárci strhla nanejvýš jednou.

Tohle chybějící propojení dodělává standardní mechanismus Salesforce, který se
spouští naplánovaným flow. V orgu Českého červeného kříže (Stripe, jinak stejné
řešení) běží od 28. 6. 2023 a má za sebou 1602 běhů; závazky tam mají navázaný
kalendář, vyplněnou další platbu a 66 budoucích splátek. V CRDM chyběl.

## Co flow dělá

`Coordinate_Gift_Commitment_Processing_Custom` je kopie standardní šablony
Salesforce, převzatá z orgu Czech Red Cross. Běží **denně o půlnoci** a spouští
tři standardní dávkové úlohy balíčku Fundraising Operations:

| Úloha | Co dělá |
| --- | --- |
| `frops_flow__UpdateCmtmtOnSchChange` | naváže na závazek jeho aktuální splátkový kalendář |
| `frops_flow__UpdateCmtmtOnNxtTxn` | doplní datum a částku další platby a asynchronně založí další splátku |
| `frops_flow__UpdateCmtmtOnTxnStatus` | přepočítá stav závazku podle posledních plateb |

Vlastní zakládání splátek řídí nastavení *Fundraising Config*
(`shouldCreateRcrSchdTrxn` = true, `installmentExtDayCount` = 1), které je
v obou orgách shodné. Splátka tedy vzniká zhruba den před splatností.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-recurring --target-org <alias>
```

V produkci se flow nasadí jako **Draft**, aktivuje se přes Tooling API PATCHem
na `FlowDefinition` s `activeVersionNumber` = 1. Po aktivaci vznikne naplánovaná
úloha `Coordinate_Gift_Commitment_Processing_Custom-1`.

## Co to nemění

Strhávání peněz zůstává na `ComgateChargePaymentsBatch` (denně 08:00 UTC, splátky
bere jen v den podle `Comgate_Settings__c.Day_Of_Charging__c`). Podmínkou je dál
`GiftCommitment.Comgate_Authorized__c = true`, což nastaví webhook po první
úspěšné platbě kartou. Závazek bez souhlasu dárce se nestrhne ani po této změně.

## Alternativa, kterou jsme nepoužili

Standardní akce *Manage Recurring Gift Commitment Schedule* (`manageRcrGiftCmtSchd`)
umí založit kalendář i první nadcházející splátku v jednom kroku. Vyžadovala by
ale zásah do `DonationPageController`, který je společný pro víc zákazníků.
Červený kříž ji také nepoužívá.
