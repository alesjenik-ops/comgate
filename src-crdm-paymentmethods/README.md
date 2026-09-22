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
Trigger `DKD_GiftTransactionPaymentMethod` (before insert, before update) ji
volá na každý dar.

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

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-paymentmethods --target-org <alias> \
  --test-level RunSpecifiedTests --tests DKD_PaymentMethodMapperTest
```

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
