# Dashboard Dary z Darujme.cz (CRDM)

Čistě OOTB reporting (žádné LWC ani Apex) nad dary, které do orgu přitečou z Darujme.cz.
Vznikl proto, že dary z Darujme v dashboardu **Platební brána Comgate** vidět nejsou a ani být
nemají: tamní reporty filtrují jen `PaymentMethod` = *Credit Card* a *Bankovní převod* a dashboard
je navíc plný – 20 komponent je strop, další se do něj nevejde.

## Odkud se dary z Darujme berou

Chodí **automaticky**, nic se neimportuje ručně:

1. Balíček Core (`CRMforNonProfit`) tahá denní synchronizací z API Darujme.cz pledge a transakce
   do `CRMforNonProfit__Darujme_Pledge__c` a `CRMforNonProfit__Darujme_Transaction__c`
   (job `Darujme_DailySyncJobComplete`, přihlašovací údaje a rozsah dnů v custom settings
   `Darujme Settings`, záznam `Global`).
2. Balíček `npc_bridge` je páruje na dárce (Account) a zakládá z nich záznamy Nonprofit Cloudu –
   joby `DarujmePledgePairingBatchable` a `DarujmeTransactionPairingBatchable`:
   - `GiftTransaction` s `PaymentMethod = Darujme` a lookupem `npc_bridge__Darujme_Transaction__c`
   - u pravidelných dárců `GiftCommitment` s `npc_bridge__Type__c = Darujme`
   - neúspěšná transakce (refund, failure, timeout…) přepne dar na `Closed Lost` a závazek na `Closed`

Když v reportech dary z Darujme nevidíte, je to tedy **buď** tím, že jste se dívali na dashboard
platební brány, **nebo** tím, že se v orgu nepřetáčí synchronizace. Ověření:

| Co ověřit | Kde |
| --- | --- |
| Běží denní synchronizace z Darujme | Setup → Scheduled Jobs → `Darujme_DailySyncJobComplete` |
| Běží párování do Nonprofit Cloudu | Setup → Scheduled Jobs → `DarujmeTransactionPairingBatchable`, `DarujmePledgePairingBatchable` |
| Chodí data | `SELECT COUNT(Id) FROM CRMforNonProfit__Darujme_Transaction__c WHERE CreatedDate = LAST_N_DAYS:7` |
| Dojdou až k darům | `SELECT COUNT(Id) FROM GiftTransaction WHERE PaymentMethod = 'Darujme' AND CreatedDate = LAST_N_DAYS:7` |
| Nezůstávají nespárované | `CRMforNonProfit__Darujme_Pledge__c` s `CRMforNonProfit__Transferred__c = false` |

## Co je uvnitř

| Složka | Obsah |
| --- | --- |
| `reports/Darujme/` | 7 reportů nad `GiftTransaction` a `GiftCommitment`, všechny filtrované na Darujme. |
| `dashboards/Darujme_Dashboards/Darujme.dashboard` | Dashboard „Dary z Darujme.cz“, 3 sloupce, running user `crdm@crmproneziskovky.cz`. |

| Report | Komponenta | Co ukazuje |
| --- | --- | --- |
| `DJ_Zaplaceno_Z_Darujme` | metrika + sloupcový graf vlevo | Zaplacené dary z Darujme po měsících. Metrika je součet částek, graf ukazuje, jestli dary chodí i teď – **prázdný poslední měsíc znamená, že se zastavila synchronizace**. |
| `DJ_Bez_Podekovani` | metrika vlevo | Zaplacené dary z Darujme bez `AcknowledgementStatus` = *Sent*. Dokud děkuje Darujme samo, je číslo vysoké; po zapnutí poděkování v SF (viz `src-crdm-thankyou`) má klesat k nule. |
| `DJ_Posledni_Dary` | tabulka uprostřed | Poslední dary seskupené podle data daru sestupně – kontrola, co a kdy naposledy přišlo. |
| `DJ_Dary_Podle_Kampane` | sloupcový graf uprostřed | Součet darů podle kampaně (projekt/promotion z Darujme se páruje na kampaň). |
| `DJ_Jednorazove_Dary` | metrika vpravo | Zaplacené dary bez závazku. |
| `DJ_Pravidelne_Dary` | metrika vpravo | Zaplacené dary navázané na závazek. |
| `DJ_Zavazky_Darujme` | donut vpravo | Pravidelní dárci z Darujme podle stavu závazku (`npc_bridge__Type__c` = Darujme). |

Jednorázové a pravidelné se rozlišují filtrem na prázdný/neprázdný `GiftCommitment`, stejně jako
v dashboardu platební brány – kvůli reportům se nezakládalo žádné pole.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-darujme --target-org <alias>
```

Závislosti, které musí být v orgu **před** nasazením:

- report typ `PB_Pravidelne_Zavazky__c` z `src-crdm-dashboard` (používá ho `DJ_Zavazky_Darujme`),
- pole `GiftCommitment.npc_bridge__Type__c` viditelné pro uživatele reportu – je v permission setu
  `Comgate Integration` (`src-comgate-npc/permissionsets`).

## Známé podmínky

- Report typy: `Gift_Transaction__c` nabízí `AcknowledgementStatus` i `GiftCommitment`, ale ne kampaň;
  `Gift_Transactions_NPC__c` naopak kampaň nabízí. Reporty jsou proto rozdělené mezi oba, stejně jako
  v `src-crdm-dashboard`.
- Časový filtr je u všech reportů „vlastní“ bez mezí, tedy celá historie. Zúžení období si uživatel
  nastaví v reportu; v metadatech se relativní intervaly schválně nepoužívají.
- Sdílení složek „Dary z Darujme.cz“ (report i dashboard) se nastavuje **ručně v UI** – metadata
  sdílení nenesou. Bez toho dashboard uvidí jen správce.
- Dashboard se na Home page nepřidává; otevírá se ze záložky Dashboards. Kdyby ho měl klient mít na
  úvodní stránce, přidá se komponenta do `Home_Platebni_Brana` (Lightning App Builder) – Home page
  s dvěma dashboardy se ale načítá znatelně pomaleji.
