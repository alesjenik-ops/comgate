# Platební metody darů (CRDM)

Jednotný tvar `GiftTransaction.PaymentMethod`: **kanál – metoda**.

| Hodnota | Kdy vznikne |
| --- | --- |
| `Comgate - Karta` | platba kartou přes bránu Comgate |
| `Comgate - Bankovní tlačítko` | bankovní tlačítko (BANK_CZ_\*) |
| `Comgate - Apple Pay` | Apple Pay |
| `Comgate - Google Pay` | Google Pay |
| `Comgate - Převod` | převod iniciovaný bránou (TRANSFER) |
| `Comgate - PayPal` | PayPal |
| `Comgate - Ostatní` | brána nahlásila metodu, kterou neznáme |
| `Darujme - Karta` | `gp_webpay_charge` |
| `Darujme - Bankovní tlačítko` | `payu_transfer` |
| `Darujme - Převod` | `funds_transfer` |
| `Darujme - Trvalý příkaz` | `csas_permanent_payment` |
| `Darujme - Ostatní` | Darujme poslalo metodu, kterou neznáme |
| `Bankovní převod` | přímý převod na účet u FIO, spárovaný z výpisu |

## Proč to tu je

Do jednoho pole zapisovaly tři kanály tři různé sady hodnot a dvě z nich mířily
na stejné slovo. `Credit Card` znamenalo kartu z Comgate, `Bankovní převod`
převod přes Comgate, `Bank Transfer` naopak převod z FIO a `Darujme` cokoli, co
přiteklo z Darujme.cz – bez ohledu na to, jestli dárce platil kartou, převodem
nebo trvalým příkazem. Rozpad na kanál a metodu dává obojí najednou: filtr přes
prefix vybere kanál, seskupení ukáže metody.

## Co to dělá

`DKD_PaymentMethodMapper` je jediné místo, kde se hodnota rozhoduje.
Trigger `DKD_GiftTransactionRules` ji volá na každý dar – a vedle ní ještě
`DKD_GiftTransactionDates` a `DKD_AccountBlacklist`, viz níže.

Kanál se pozná podle zdroje, ne podle toho, co v poli je:

1. vyplněný `npc_bridge__SourceFpackTransaction__c` → FIO → `Bankovní převod`
2. `npc_bridge__Darujme_Transaction__c` → Pledge → `CRMforNonProfit__Payment_Method__c`;
   u splátek, které na transakci nevisí, se bere Pledge ze závazku
3. Comgate se pozná podle `ProcessorReference`, `Comgate_Transaction_Id__c`,
   `Comgate_Variable_Symbol__c` nebo podle závazku. Metoda se čte v pořadí
   `GiftTransaction.Payment_Method__c` → `GiftCommitment.Payment_Method__c` →
   volba dárce z `Payment_Reference__c.JSON_Payment_Wrapper__c`

Když se kanál rozpoznat nedá, pole se **nechá být** – ručně zadaný dar
(`Cash`, `Check`) si trigger nepřepíše.

Trigger nesahá na hodnoty mimo tuhle sadu. Přepisuje jen prázdné pole, staré
hodnoty (`Credit Card`, `Bank Transfer`, `Darujme`, `Unknown`, `Online Bank`)
a hodnoty, které sám dopočítal – jinak by webhook nemohl zpřesnit metodu,
kterou při zakládání daru ještě nikdo neznal.

## Proč trigger, a ne úprava integrace

Dary z Darujme i spárované převody z FIO zakládá **managed balíček**
`npc_bridge`; `FpackTransactionPairingQueueable` i `DarujmeTransactionPairingQueueable`
mají hodnotu natvrdo a obě třídy jsou `public`, ne `global`, takže se z orgu
nedají ani zavolat, ani obejít. Trigger je jediné místo, kam na jejich zápis
dosáhneme. Comgate integrace se tím pádem nemusela měnit vůbec – webhook dál
zapisuje surovou hodnotu do `Payment_Method__c` a trigger si ji přečte.

## Očekávané datum platby u převodů

`DKD_GiftTransactionDates` doplní nezaplacenému daru `TransactionDate` podle
splatnosti, pokud je platební metoda **převod** (`Comgate - Převod`,
`Bankovní převod`, `Bank Transfer`).

Zní to jako nesmysl – datum přijetí peněz na daru, který ještě nikdo nezaplatil.
Je to ale jediné pole, na které se dívá párování bankovních výpisů v balíčku
(`FpackTransactionPairingQueueable`, řádky 112–114):

```apex
Status = 'Unpaid' AND
TransactionDate >= :minOppDate AND
TransactionDate <= :maxOppDate AND
DonorId IN :accountIds
```

Darovací formulář plní jen `TransactionDueDate`, `TransactionDate` nechává
prázdné. Prázdné datum téhle podmínce nikdy nevyhoví, takže párování dar
z formuláře neuvidí a místo označení za zaplacený **založí druhý**. Takhle
vzniklo deset duplicitních darů za 16 800 Kč – stejný dárce, stejná částka,
jednou Unpaid z formuláře a podruhé Paid z výpisu.

Dokud dar není zaplacený, je to prostě očekávané datum platby. Jakmile platba
dorazí, přepíše ho párování skutečným datem z výpisu
(`FpackTransactionPairingQueueable` ř. 174) nebo Comgate webhook
(`ComgateWebhook` ř. 242).

U karet se datum neplní – ty vyřídí webhook během několika minut a párování
výpisů do nich nemá co sahat.

Historické dary dožene `DKD_GiftTransactionDates.backfill()`; je idempotentní.

## Blacklist protiúčtů

Na účet u FIO chodí i platby, které nejsou dary: **zúčtování platební brány
Comgate** a **výplaty z Darujme.cz přes Nadaci VIA**. Párování je připsalo
záložnímu účtu *Default* a udělalo z nich dary – peníze se tím počítaly dvakrát,
protože jednotlivé karetní a Darujme dary už v CRM jsou.

Seznam účtů, ze kterých se dary nezakládají, drží standardní pole
`CRMforNonProfit__NNOSettings__c.Account_Num_Blacklist__c` (*NNO Settings →
Account Num. Blacklist*). Čísla účtů se oddělují novým řádkem, čárkou nebo
středníkem, s kódem banky i bez něj. Aktuálně:

```
2107358917/2700   Comgate a.s.
2198370339/0800   Nadace VIA
```

**Samotné nastavení párování nezastaví.** `FpackTransactionPairingQueueable`
i `EntityPairing` v balíčku `npc_bridge` čtou z NNO Settings jen tři výchozí
lookupy (`DefaultContact`, `DefaultAccount`, `DefaultCampaign`) a blacklist
ignorují. Dar proto vznikne a `DKD_AccountBlacklist` ho hned zahodí – běží
v `after insert`, protože `before insert` zápis zrušit neumí a `addError` by
shodil celý `upsert` dávky v balíčku.

Bankovní transakce v `CRMforNonProfit__Transaction__c` zůstává, jen z ní není dar.

Dary, které vznikly dřív, než se blacklist zavedl, dožene
`DKD_AccountBlacklist.discardExisting()`; je idempotentní.

Kandidát na doplnění: `133070299/2010` (Česká rada dětí a mládeže) – vlastní
převod 20 000 Kč mezi účty organizace.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-paymentmethods --target-org <alias> \
  --test-level RunSpecifiedTests --tests DKD_PaymentMethodMapperTest \
  --tests DKD_GiftTransactionDatesTest
```

Složka obsahuje i `destructiveChangesPost.xml`, který maže starý trigger
`DKD_GiftTransactionBefore`. Trigger se jmenuje `DKD_GiftTransactionRules`,
protože kromě platební metody řeší i datum a blacklist – a už neběží jen
v `before` kontextu.

Číselník `PaymentMethodType` je standardní value set – v manifestu musí být
vyjmenovaný jménem, wildcard retrieve ho nevrátí a pod objektem `GiftTransaction`
ani pod jménem `PaymentMethod` ho nenajdeš.

## Migrace historických dat

```apex
System.debug(DKD_PaymentMethodMapper.migrate());          // GiftTransaction
System.debug(DKD_PaymentMethodMapper.migrateSchedules()); // GiftCommitmentSchedule
```

Obojí je idempotentní. `migrateSchedules()` ale většinou neudělá nic –
Salesforce pole na kalendáři zamyká, jakmile má splátky („You can't edit this
field because the schedule has transactions“). Na výsledku to nic nemění,
hodnotu na samotné splátce srovná trigger.

Hromadný update statusem daru nehýbe, takže **nespustí děkovné e-maily** –
flow `Gift Transaction Thank You Email` má `doesRequireRecordChangedToMeetCriteria`
a reaguje jen na přechod do `Paid`. Ověřeno při migraci 766 darů: neodešel
žádný e-mail.

## Co se muselo upravit jinde

- **Reporty** *Platební brána* (10×) a *Darujme* (6×) filtrovaly na konkrétní
  hodnoty. Nově jsou na `startsWith` `Comgate -` / `Darujme -`.
- **Flow `Gift Transaction Thank You Email`** vynechává dary z Darujme
  podmínkou na platební metodu. `NotEqualTo 'Darujme'` by po rozpadu propustilo
  úplně všechno, a Darujme dárcům by začala chodit poděkování, která jim posílat
  nemáme. Flow nemá operátor „nezačíná na“, proto je podmínka přes formuli
  `Neni_Darujme` = `NOT(BEGINS(TEXT(PaymentMethod), "Darujme"))`.
  Živá verze flow je v `src-crdm-thankyou/flows/`; ta v `phase2/` je novější
  a zatím nenasazená.
- **`DKD_GiftThankYouScheduler`** měl v SOQL `PaymentMethod != 'Darujme'`,
  nově `NOT PaymentMethod LIKE 'Darujme%'`.

## Proč je v číselníku i `Bank Transfer`

`FpackTransactionPairingQueueable` (balíček `npc_bridge`, řádek 199) nastavuje
natvrdo `PaymentMethod = 'Bank Transfer'`. Než tahle hodnota do číselníku
přibyla, padalo denní párování bankovních výpisů z FIO na

```
INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST, Payment Method:
bad value for restricted picklist field: Bank Transfer: [PaymentMethod]
```

a **žádná platba z FIO se nestala darem**. Trigger dnes hodnotu přepíše na
`Bankovní převod` ještě před zápisem, takže v datech nikdy neskončí – v číselníku
ji ale necháváme jako pojistku pro případ, že by trigger byl vypnutý.

## Co zůstalo jak bylo

`GiftTransaction.Payment_Method__c` a `GiftCommitment.Payment_Method__c` dál
drží surovou hodnotu z Comgate (`CreditCard`, `Apple Pay`, `Bank Transfer`…).
Jsou to vstupy pro mapování, ne výstup, a reporty nad `Payment_Log__c` na nich
stojí.
