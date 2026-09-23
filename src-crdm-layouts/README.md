# Stránky dárce a kampaně (CRDM)

Souhrn z Data Processing Engine pryč, místo něj pole balíčku fpack Analytics.

## Co se změnilo

| Komponenta | Před | Po |
| --- | --- | --- |
| `Account_Record_Page`, `Account_Record_Page1` | komponenta *Donor Gift Summary* (`runtime_industries_fundraising:relatedRecordDetailDisplay`, vazba `DonorGiftSummary:DonorId`) | sekce **Analytika dárců (fpack)** s 26 poli `fpnpc_analytics__*` ve dvou sloupcích |
| `Campaign-Campaign Layout` | bez analytiky | sekce **Analytika dárců (fpack)** s 22 poli `fpnpc_analytics__*` |

*Outreach Summary* nikde na stránkách nebyl, objekt v orgu nemá jediný záznam.

## Pozor: pole jsou zatím prázdná

Balíček **FundraisingPack Analytics 1.3.0.1** je nainstalovaný a jeho denní dávky
běží bez chyby, ale nic nepočítají:

- `fpnpc_analytics__Gift_Type_Settings__mdt` – **0 záznamů**, přitom určuje, který
  typ daru se počítá do finančních darů. Pole `Donor_History_Field__c` má
  `fieldManageability = DeveloperControlled`, takže do něj zákaznický org **nesmí
  zapisovat** (ověřeno: záznam bez hodnot se nasadí, se zadanou hodnotou skončí
  `UNKNOWN_EXCEPTION`).
- `fpnpc_analytics__Donor_Level__mdt` – 0 záznamů, stejné omezení.
- `fpnpc_analytics__Donor_History__c` – 0 záznamů.

Ověřeno i to, že problém není jinde: `DonorStatsCalculator.computeUpdates()` vrátí
pro dárce se 45 zaplacenými dary nula aktualizací, `DonorHistoryBackfillBatch.runBatch()`
doběhne bez chyby a nevytvoří nic, a doplnění chybějící `GiftTransactionDesignation`
na výsledek nemá vliv.

**Dokud dodavatel balíčku nedoplní Gift Type Settings, zůstanou pole na stránkách prázdná.**

## Alternativa, kdyby se čekání protáhlo

Standardní souhrn Salesforce (`DonorGiftSummary`) plní Data Processing Engine.
V CRDM není definovaná žádná (`BatchCalcJobDefinition` = 0), proto byl souhrn
prázdný i předtím. Org Czech Red Cross má definici `DonorGiftSummaryCustom` a denní
flow *Daily Donor Gift Summary*, díky čemuž má přes 72 000 souhrnných záznamů.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-layouts --target-org <alias>
```

## Pole fpack analytics na kampani

Balíček nabízí od každé metriky tři varianty a jejich význam je v popisu pole:

| Přípona | Co počítá |
| --- | --- |
| bez přípony | jen tuhle kampaň |
| `_H` | jen podřízené kampaně pod ní |
| `_All` | tuhle kampaň **včetně celé hierarchie** |

Na layoutu *Campaign Layout* zůstalo **10 polí**: šest `_All` a čtyři průměry.
Dvanáct polí bez přípony a `_H` je pryč – `_All` je jejich součet, u plochých
kampaní se rovná variantě bez přípony a `_H` je tam vždy nula. Hierarchii má
v orgu jen *DKD - darujme.cz* s pěti potomky, dary přitom leží na plochých
kampaních *DKD - home* a *DKD - Jeden klik*.

Reporty na dashboardu *NPC Analytics — výroční zpráva* stojí taky na `_All`,
takže layout i reporting ukazují totéž.

Balíčkový layout *FPack Campaign* (namespace `CRMforNonProfit`) žádná pole
z fpack analytics nemá a profil Admin ho nepoužívá – Campaign má přiřazený
*Campaign Layout*.
