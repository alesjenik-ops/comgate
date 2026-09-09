# Dashboard Platební brána Comgate

Čistě OOTB reporting (žádné LWC ani Apex) nad provozem platební brány v CRDM orgu.

## Co je uvnitř

| Složka | Obsah |
| --- | --- |
| `reports/Platebni_Brana/` | 13 reportů nad `Payment_Reference__c` (pokusy o platbu), `Payment_Log__c` (události z Comgate) a `GiftTransaction` (dary z brány). |
| `dashboards/Platebni_Brana_Dashboards/Platebni_Brana.dashboard` | Dashboard „Platební brána Comgate“, 3 sloupce, running user `crdm@crmproneziskovky.cz`. |
| `objects/Payment_Reference__c.object` | Objekt se zapnutým *Allow Reports* – bez toho nad ním reporty nejdou. |
| `phase2a/flexipages/Home_Platebni_Brana.flexipage` | Home page s embedovaným dashboardem, odvozená z `Home_Page_Default`. |

## Nasazení

Pořadí je závazné – home page se validuje proti dashboardu, který už musí v orgu být:

```bash
sf project deploy start --metadata-dir src-crdm-dashboard --target-org <alias>
sf project deploy start --metadata-dir src-crdm-dashboard/phase2a --target-org <alias>
```

## Aktivace home page – ručně

Přiřazení home page aplikaci přes `CustomApplication.actionOverrides`
(`standard-home`) org odmítá ve všech vyzkoušených tvarech (app-level, per profile,
tvar generovaný App Builderem). Aktivuje se v UI:

Setup → Lightning App Builder → *Home – Platební brána* → Activation → záložka
*App Default* → přidat aplikaci **CRDM** (případně *Org Default*) → Save.

## Poznámky k datům

- Testovací platby (`Payment_Log__c.Is_Test__c`) jsou ze všech čísel vyloučené a
  zobrazené zvlášť v donutu vpravo dole.
- Import z Darujme (`PaymentMethod = Darujme`) do brány nepatří, reporty nad
  `GiftTransaction` filtrují jen `Credit Card` a `Bankovní převod`.
- Důvod havárie (`Status_Reason__c`) je long text, nejde seskupit – je ve sloupci
  tabulkového reportu *Havarované platby – detail s důvodem*, na který vede proklik
  z metriky.
- Kampaň u `Payment_Reference__c` je textové ID; „odkud dárci přišli“ se proto čte
  z `GiftTransaction.Campaign`.
