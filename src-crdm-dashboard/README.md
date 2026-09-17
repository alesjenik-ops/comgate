# Dashboard Platební brána Comgate

Čistě OOTB reporting (žádné LWC ani Apex) nad provozem platební brány v CRDM orgu.

## Co je uvnitř

| Složka | Obsah |
| --- | --- |
| `reports/Platebni_Brana/` | 18 reportů nad `Payment_Reference__c` (pokusy o platbu), `Payment_Log__c` (události z Comgate) a `GiftTransaction` (dary z brány). |
| `dashboards/Platebni_Brana_Dashboards/Platebni_Brana.dashboard` | Dashboard „Platební brána Comgate“, 3 sloupce, running user `crdm@crmproneziskovky.cz`. |
| `objects/Payment_Reference__c.object` | Objekt se zapnutým *Allow Reports* – bez toho nad ním reporty nejdou. |
| `phase2/flexipages/Home_Platebni_Brana.flexipage` | Home page s embedovaným dashboardem, odvozená z `Home_Page_Default`. |
| `rejected/applications/CRDM.app` | Pokus přiřadit home page aplikaci přes `actionOverrides`. Org ho odmítá, **nenasazovat** – je tu jen jako záznam, co nefunguje. |

## Nasazení

Pořadí je závazné – home page se validuje proti dashboardu, který už musí v orgu být:

```bash
sf project deploy start --metadata-dir src-crdm-dashboard --target-org <alias>
sf project deploy start --metadata-dir src-crdm-dashboard/phase2 --target-org <alias>
```

Stav k 16. 9. 2026: obě části jsou v CRDM orgu nasazené a shodné s repem.

## Aktivace home page – ručně

Přiřazení home page aplikaci přes `CustomApplication.actionOverrides`
(`standard-home`) org odmítá ve všech vyzkoušených tvarech (app-level, per profile,
tvar generovaný App Builderem). Aktivuje se v UI:

Setup → Lightning App Builder → *Home – Platební brána* → Activation → záložka
*App Default* → přidat aplikaci **CRDM** (případně *Org Default*) → Save.

Jestli je aktivace hotová, se z CLI ověřit nedá (objekt `FlexiPageAssignment` org
nenabízí), je potřeba se podívat do Setupu.

## Přehled darů a hlídání poděkování

Pět reportů nad report typem `Gift_Transaction__c` (ten na rozdíl od
`Gift_Transactions_NPC__c` nabízí `AcknowledgementStatus` i `GiftCommitment`).
Všechny filtrují jen dary z brány, tedy `PaymentMethod` = *Credit Card* nebo
*Bankovní převod*; importy z Darujme jsou mimo.

| Report | Komponenta | Co ukazuje |
| --- | --- | --- |
| `PB_Bez_Podekovani` | metrika vlevo | Zaplacené dary, které nemají `AcknowledgementStatus` = *Sent*. Hlídá výpadky automatiky – **má být 0**, prokliknutím se dostanete na seznam. |
| `PB_Dary_Podle_Stavu` | donut vlevo | Všechny dary z brány podle stavu (Paid / Unpaid / Failed). |
| `PB_Dary_Podle_Metody_A_Stavu` | sloupcový graf uprostřed | Matice metoda × stav – kolik karet a převodů skončilo zaplacením a kolik ne. |
| `PB_Pravidelne_Dary` | metrika vpravo | Zaplacené dary navázané na závazek (pravidelné). |
| `PB_Jednorazove_Dary` | metrika vpravo | Zaplacené dary bez závazku (jednorázové). |

Pravidelné a jednorázové se rozlišují filtrem na prázdný/neprázdný `GiftCommitment`,
ne novým polem – žádné pole se kvůli dashboardu nezakládalo.

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
