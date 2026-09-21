# Číselník platebních metod (CRDM)

Hodnota `Bank Transfer` v `PaymentMethodType`, bez které nešly do CRM převést
platby z FIO.

## Proč to tu je

Balíček `npc_bridge` páruje bankovní výpisy z FIO na dárce dávkou
`FpackTransactionPairingBatchable` (denně 05:00). Nalezené platby zakládá jako
`GiftTransaction` a natvrdo jim nastavuje

```apex
opp.PaymentMethod = 'Bank Transfer';   // FpackTransactionPairingQueueable, radek 199
```

V orgu ale tahle hodnota v číselníku nebyla – byl tam jen český
`Bankovní převod`, který do stejného pole zapisuje integrace Comgate. Dávka
proto každý den spadla na

```
INVALID_OR_NULL_FOR_RESTRICTED_PICKLIST, Payment Method:
bad value for restricted picklist field: Bank Transfer: [PaymentMethod]
```

a **žádná platba z FIO se nikdy nestala darem**. V objektu
`CRMforNonProfit__Transaction__c` ležely, ale v `GiftTransaction` chyběly.

## Kde ten číselník je

Pole `GiftTransaction.PaymentMethod` je standardní a bere hodnoty ze
**standardního číselníku `PaymentMethodType`**, ne z definice objektu. Proto ho
nenajdeš v `objects/GiftTransaction.object` ani pod jménem `PaymentMethod`;
`listMetadata StandardValueSet` ani wildcard retrieve ho taky nevrátí – musí se
vyjmenovat v manifestu jménem `PaymentMethodType`.

Číselník má nově 14 hodnot: 13 původních (mezi nimi `Bankovní převod`
a `Darujme`) plus `Bank Transfer`.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-picklists --target-org <alias>
```

## Dopad na reporty

V poli teď žijí **dvě hodnoty se stejným významem**:

| Hodnota | Kdo ji zapisuje |
| --- | --- |
| `Bankovní převod` | integrace Comgate – bankovní převod přes platební bránu |
| `Bank Transfer` | `npc_bridge` – přímý převod na účet u FIO |

Není to duplicita k odstranění, jsou to dva různé kanály. Reporty na dashboardu
*Platební brána* proto dál filtrují jen `Credit Card,Bankovní převod` – platby
z FIO branou neprošly. Reporty *Dary po měsících dle metody* a *Nezaplacené dary
dle metody* na `Fundraising Dashboard` filtrují jen podle stavu a metodu
seskupují, takže `Bank Transfer` se v nich objeví sám.

## Omezení dávky

`FpackTransactionPairingBatchable.start()` bere jen transakce za posledních
`BatchSettings__mdt.FpackTransactionPairingDays__c` dní, **výchozí hodnota je
10** a v orgu žádný záznam `Global` není. Všechna pole toho custom metadata typu
mají `fieldManageability = DeveloperControlled`, takže je subscriber nastavit
nemůže; `FpackTransactionPairingQueueable` i `EntityPairing` jsou `public`, ne
`global`, takže z anonymního Apexu v orgu nejsou dosažitelné.

Starší transakce tedy dávka nedožene. Pokud to bude potřeba, řeší se to novou
verzí balíčku (okno konfigurovatelné bez CMDT, nebo `global` vstupní bod).
