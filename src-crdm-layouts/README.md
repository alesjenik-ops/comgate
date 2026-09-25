# Stránky dárce a kampaně (CRDM)

Souhrn z Data Processing Engine pryč, místo něj pole balíčku fpack Analytics.

## Co se změnilo

| Komponenta | Před | Po |
| --- | --- | --- |
| `Account_Record_Page`, `Account_Record_Page1` | komponenta *Donor Gift Summary* (`runtime_industries_fundraising:relatedRecordDetailDisplay`, vazba `DonorGiftSummary:DonorId`) | sekce **Analytika dárců (fpack)** s 26 poli `fpnpc_analytics__*` ve dvou sloupcích |
| `Campaign-Campaign Layout` | bez analytiky | sekce **Analytika dárců (fpack)** s 22 poli `fpnpc_analytics__*` |

*Outreach Summary* nikde na stránkách nebyl, objekt v orgu nemá jediný záznam.

## Plnění polí

Dlouho byla pole prázdná: balíček počítá jen dary s platební metodou ve whitelistu
`fpnpc_analytics__Gift_Type_Settings__mdt` a ten byl v CRDM prázdný. Whitelist
s hodnotami CRDM je ve složce `src-crdm-analytics-config` – bez jejího nasazení
zůstanou pole na stránkách prázdná. Detail a kontrolní dotazy jsou v jejím README.

## Alternativa, kdyby se čekání protáhlo

Standardní souhrn Salesforce (`DonorGiftSummary`) plní Data Processing Engine.
V CRDM není definovaná žádná (`BatchCalcJobDefinition` = 0), proto byl souhrn
prázdný i předtím. Org Czech Red Cross má definici `DonorGiftSummaryCustom` a denní
flow *Daily Donor Gift Summary*, díky čemuž má přes 72 000 souhrnných záznamů.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-layouts --target-org <alias>
```

## Stránka kampaně (*Campaign Layout*)

Na layoutu zůstala jen pole, která se v CRDM plní.

| Sekce | Pole | Kdo je plní |
| --- | --- | --- |
| Campaign Information | vlastník, název, nadřazená kampaň, typ, začátek, aktivní, stav, měna, konec | uživatel |
| Description Information | popis | uživatel |
| Analytika dárců (fpack) | 10 polí – vlevo jednorázové, vpravo pravidelné dary | noční pipeline fpack analytics |
| Campaign Statistics | počet kontaktů, počet odpovědí | Salesforce z členů kampaně |
| System Information | vytvořil, naposledy změnil | Salesforce |

Pryč jsou statistiky leadů a příležitostí (NPC dary nejsou `Opportunity`, čísla
byla vždy nulová), plánovací pole (`NumberSent`, `ExpectedResponse`,
`ExpectedRevenue`, `BudgetedCost`, `ActualCost`), prázdné sekce *Additional
Information* a *Other Information* a sekce *Custom Links* – obě classic odkazy,
*Campaign Influence* navíc stojí na příležitostech. Z related listu hierarchie
kampaní zmizely sloupce leadů, příležitostí a nákladů, ze seznamu členů kampaně
titul, firma a rozdělené jméno.

**Tlačítka.** Layout má vlastní `platformActionList`, takže pořadí akcí
v Lightningu určuje on: **Send Email** první, pak Edit, Clone, Change Owner,
Delete, Log a Call, New Task a New Event. Akce, které v seznamu nejsou (třeba
*Send Bulk SMS* z `npc_bridge`), se na kampani přestanou ukazovat – případně je
doplň v *Salesforce Mobile and Lightning Experience Actions*.

**Related listy** v pořadí: hierarchie kampaní, **Gift Transactions** (dárce,
částka, datum, platební metoda, stav – nejnovější nahoře), **Gift Commitments**
(dárce, stav, očekávaná částka, začátek), členové kampaně, aktivity, historie
aktivit, přílohy.

### Varianty polí fpack analytics

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
