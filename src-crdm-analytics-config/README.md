# Typy darů pro fpack analytics (CRDM)

Bez téhle složky balíček **fpack analytics** (`fpnpc_analytics`) v CRDM nespočítá
nic. Pole na kampani, na dárci i roční historie zůstávají prázdná nebo nulová.

## Proč byla pole prázdná

Každý krok analytiky (`CampaignAnalyticsBatch`, `DonorStatsBatch`,
`DonorScenarioAnalyticsBatch`, `DonorHistoryBackfillBatch`,
`GiftCommitmentAssignmentBatch`) bere jen dary, jejichž `PaymentMethod` je
ve whitelistu `fpnpc_analytics__Gift_Type_Settings__mdt`
(`DonorAnalyticsConfig.financialTypes()`). Když je whitelist prázdný, batch se
záměrně nespustí, aby hodnoty nepřepsal nulami.

V CRDM byl whitelist prázdný ze dvou důvodů:

1. **Balíček žádné záznamy nedodal.** Ve zdroji jich je 11, ale balíček je 1GP
   a záznamy custom metadata se do něj musí přidat ručně. To se nestalo.
2. **Ani výchozí záznamy by nestačily.** Mapují standardní hodnoty (`Cash`,
   `Credit Card`, `ACH`…), jenže CRDM používá vlastní tvar **kanál – metoda**
   (`Comgate - Karta`, `Bankovní převod`, `Darujme - Trvalý příkaz`…), viz
   `src-crdm-paymentmethods`. Na žádnou z nich by se výchozí záznam netrefil.

## Co složka obsahuje

26 záznamů, jeden na každou hodnotu číselníku `PaymentMethodType` v CRDM.
Label záznamu je **přesně hodnota `PaymentMethod`**, tak ji balíček porovnává.

| Kategorie (`Donor_History_Field__c`) | Hodnoty |
| --- | --- |
| Financial Donations | všechny kromě `In-Kind` – 13 hodnot Comgate a Darujme, `Bankovní převod`, staré hodnoty (`Credit Card`, `Bank Transfer`, `Darujme`, `Unknown`) a zbylé standardní hodnoty |
| In Kind Donations | `In-Kind` |

Staré hodnoty zůstávají ve whitelistu i po migraci – kdyby se někde objevily,
dar se pořád započítá.

**Když přibude nová platební metoda** (hodnota v `PaymentMethodType`), musí
přibýt i záznam tady. Jinak se dary s touhle metodou do analytiky nezapočítají
a nic na to neupozorní.

## Proč to projde, i když README analytiky tvrdilo opak

V `src-crdm-analytics/README.md` stálo, že záznamy doplnit nemůžeme:
`Donor_History_Field__c` má `fieldManageability = DeveloperControlled`, pokus
skončil `UNKNOWN_EXCEPTION` a describe vrací `createable: false`.

- `createable: false` vrací describe u **každého** custom metadata typu; záznamy
  se přes DML nezakládají nikdy. O tom, jestli jde nasadit záznam, to nic neříká.
- `DeveloperControlled` zamyká hodnotu jen u záznamů, které **přišly
  s balíčkem**. Záznam založený v subscriber orgu patří subscriberovi a smí
  do něj zapsat cokoli.
- `UNKNOWN_EXCEPTION` bez chyb komponent je známý gack při chybějící deklaraci
  `xmlns:xsd` v kořeni záznamu (`<value xsi:type="xsd:string">` ji potřebuje).
  Balíček na něj narazil taky (commit `7463b2e` v repu analytiky). Soubory tady
  deklaraci mají.

Když deploy **přesto** spadne na manageability, je potřeba úprava v balíčku:
v packaging orgu přepnout pole na `SubscriberControlled` (nebo přidat tyhle
záznamy do balíčku), vydat novou verzi a upgradovat CRDM.

## Nasazení

Workbench → Deploy, **Single Package** a **Rollback On Error**. Kód v tom není,
takže testy nejsou potřeba.

```bash
sf project deploy start --metadata-dir src-crdm-analytics-config --target-org <alias>
```

Pak jednou ručně spustit pipeline (Developer Console → Execute Anonymous), ať se
na výsledek nečeká do noci:

```apex
fpnpc_analytics.DonorAnalyticsScheduler.runChainNow();
```

Řetěz jede v pěti krocích za sebou, poslední je `CampaignAnalyticsBatch`.
Hotovo je, když v *Apex Jobs* doběhne `CampaignAnalyticsBatch`.

## Kontrola

```sql
SELECT Name,
       fpnpc_analytics__Total_Donations_Amount_One_Off_All__c,
       fpnpc_analytics__Total_Donors_One_Off_All__c,
       fpnpc_analytics__Total_Donations_Amount_Regular_All__c,
       fpnpc_analytics__Total_Donors_Regular_All__c
FROM Campaign
WHERE IsActive = true
```

Pro srovnání přímo z darů (jen zaplacené, jen tahle kampaň bez hierarchie):

```sql
SELECT CampaignId, Campaign.Name, COUNT(Id), SUM(OriginalAmount)
FROM GiftTransaction
WHERE Status = 'Paid'
GROUP BY CampaignId, Campaign.Name
```

## Co se tím spustí navíc

Whitelist zapne **celou** pipeline, ne jen kampaně:

- **Dárci** – plní se pole `fpnpc_analytics__*` na Accountu (sekce *Analytika
  dárců (fpack)* na stránce dárce) a scénář dárce. Dnes mají všichni scénář
  *Non - Donor*, po prvním běhu se to rozpadne podle skutečných darů.
- **Roční historie** – vzniknou záznamy `fpnpc_analytics__Donor_History__c`,
  dashboardy *NPC Analytics* se naplní.
- **Automatické závazky** – `GiftCommitmentAssignmentBatch` najde opakované dary
  se stejným dárcem, kampaní a částkou (typicky trvalé příkazy přes FIO bez
  závazku) a založí k nim `GiftCommitment` s `Analytics_Type__c = 'Automatic'`
  a jménem *Recurring Gift <datum>*. Dar k němu připojí jen přes vlastní pole
  `fpnpc_analytics__Gift_Commitment__c`; standardní `GiftCommitmentId`,
  na kterém stojí poděkování (`Gift Transaction Thank You Email`), nemění.
  Závazky z Comgate a Darujme (prázdné `Analytics_Type__c`) nechává být.
  V related listu *Gift Commitments* a v reportech nad závazky se ale tyhle
  záznamy objeví – odlišíš je podle `Analytics_Type__c`.

Volitelně: záložní účet *Default*, na který párování dává nerozpoznané platby,
se dá z počtu dárců vyřadit (dary zůstanou v částkách):

```apex
insert new fpnpc_analytics__Donor_Analytics_Settings__c(
    Name = 'Default',
    fpnpc_analytics__Default_Donor_Account_Id__c = '<Id účtu Default>');
```
