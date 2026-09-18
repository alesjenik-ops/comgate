# Poděkování za dar s potvrzením (CRDM)

Automatický děkovný e-mail po zaplaceném daru: u **jednorázového** s PDF potvrzením o daru,
u **pravidelného** jednou za závazek při první zaplacené platbě (bez PDF).
Podle šablon `děkovný dopis individuální dárce jednorázový.docx` a `potvrzení o daru DKD.docx` (9/2026).

## Jak to běží

1. Comgate webhook přepne `GiftTransaction.Status` na `Paid`.
2. Flow `Gift_Transaction_Thank_You_Email` (record-triggered) běží **asynchronně až po commitu**
   (`Run Asynchronously After Transaction`), takže jeho selhání **nikdy neshodí zápis platby z webhooku**.
   Jednorázový i pravidelný dar s `AcknowledgementStatus != Sent` volají **tutéž** invocable metodu
   `DKD_GiftThankYouService`. Flow běží jako guest user site (ten zapsal platbu z webhooku) a ten nemá
   práva e-mail poslat, proto invocable metoda jen **publikuje platform event
   `DKD_Thank_You_Requested__e`**. Jeho trigger `DKD_ThankYouRequestedTrigger` běží díky
   `PlatformEventSubscriberConfig` jako správce (`crdm@crmproneziskovky.cz`) a zařadí Queueable.
   E-mail tak odchází **během několika sekund po platbě**. Dary importované z Darujme.cz
   projdou jen tehdy, když je zapnuté poděkování za Darujme – viz níže.
3. Typ daru rozliší **Apex** podle `GiftCommitmentId` – ve flow už žádné odesílání e-mailu není:
   - **jednorázový dar** – PDF ze šablony `npc_bridge__PDF_Template__c` „Potvrzeni o daru DKD" přes VF
     stránku balíčku `GiftConfirmationPDF`, e-mail `DKD_Thank_You_One_Time`, PDF se uloží jako soubor
     k transakci, nastaví se `AcknowledgementStatus` i `TaxReceiptStatus = Sent`
   - **pravidelný dar** – **jednou za závazek**, e-mail `DKD_Thank_You_Recurring` **bez PDF**,
     nastaví se jen `AcknowledgementStatus` a `AcknowledgementDate`; `TaxReceiptStatus` zůstává.
     O přeskočení rozhoduje, jestli **některá platba závazku už má `AcknowledgementStatus = Sent`** –
     záměrně ne pořadí splatnosti: splátky se platí i mimo pořadí (neúspěšná splátka zůstává `Unpaid`
     a `ComgateChargePaymentsBatch` ji nabíjí později), takže podle `TransactionDueDate` by zaplacení
     starší splátky poslalo druhé poděkování za tentýž závazek.

   Merge pole `{!GiftTransaction.X}` se u obou šablon plní přímo z transakce, e-mail se posílá
   z organizační adresy `darci@darujemekrouzky.cz` (jen pokud je ověřená) a ukládá se jako
   **EmailMessage pod kontakt dárce**.
4. Dozorčí job `DKD_GiftThankYouScheduler` (každých 15 min, běží jako admin) je pojistka: dobere dary,
   u kterých event nedorazil nebo odeslání spadlo. Stav `Sent` se zapisuje před odesláním – bez rizika duplicit.
   **Pokrývá jen jednorázové dary** (`GiftCommitmentId = null`) – viz Známé podmínky.

## Dary z Darujme.cz

Dary z Darujme.cz (`PaymentMethod = Darujme`, zakládá je párovací job balíčku `npc_bridge`)
se řídí jedním přepínačem: custom setting **DKD poděkování – nastavení**
(`DKD_Thank_You_Settings__c`), pole **Poděkování za Darujme od**
(`Darujme_Thank_You_From__c`).

| Hodnota | Co se děje |
| --- | --- |
| prázdné (výchozí) | Za dary z Darujme se **neděkuje** – dárcům píše Darujme.cz samo. Platí pro jednorázové i pravidelné. |
| datum | Děkujeme za dary **darované od toho dne**, jednorázové s PDF potvrzením, pravidelné jednou za závazek. Starší dary zůstávají bez e-mailu. |

Rozhoduje **datum daru** (`TransactionDate`), ne datum vzniku záznamu: denní synchronizace
z Darujme dotahuje i několik dní staré dary a na ty už potvrzení z Darujme odešlo. Kdyby
rozhodovalo datum importu, rozeslali bychom druhé poděkování k darům, které už poděkované jsou.

Přepínač hlídají tři místa, aby se nedalo obejít: podmínka ve flow (`$Setup`), `DKD_GiftThankYouService`
při vlastním zpracování a dotaz dozorčího jobu.

### Zapnutí

Pořadí je podstatné, jinak dárce dostane dva e-maily, nebo žádný:

1. Domluvit s organizací den, kdy si **vypne potvrzení na straně Darujme.cz**.
2. Tentýž den vyplnit `Darujme_Thank_You_From__c` v Setup → Custom Settings → *DKD poděkování –
   nastavení* → Manage → New/Edit (org default).
3. Zkontrolovat report `DJ_Bez_Podekovani` (`src-crdm-darujme`) – po zapnutí má klesat k nule.

Vypnutí je stejně snadné: pole vyprázdnit. Dary, které v mezidobí přišly, už poděkování mít budou.

## Obsah

| Cesta | Co |
| --- | --- |
| `objects/GiftTransaction.object` | 6 formula polí: oslovení, částka text, rok, jméno/e-mail/adresa dárce pro potvrzení |
| `classes/` | `DKD_GiftThankYouService`, `…Queueable`, `…Scheduler`, test (pokrytí 90–94 %) |
| `objects/DKD_Thank_You_Requested__e.object` | platform event s `Gift_Transaction_Id__c`, publikuje se po commitu |
| `objects/DKD_Thank_You_Settings__c.object` | custom setting s datem zapnutí poděkování za dary z Darujme |
| `triggers/DKD_ThankYouRequestedTrigger` | odběratel eventu, jen předá Id do `DKD_GiftThankYouService.handleRequestedEvents` |
| `PlatformEventSubscriberConfigs/DKD_ThankYouRequested_Admin` | trigger běží jako `crmproneziskovky` správce, ne jako Automated Process – **bez toho e-mail z guest kontextu neodejde** |
| `staticresources/` | `CRDM_Logo` (z ContentAsset aplikace), `CRDM_Signature_Sejtka` (z docx šablony) |
| `permissionsets/DKD_Thank_You_Automation` | FLS na nová pole, třídy balíčku a Create na platform event – **přiřazeno adminovi a guest userovi site** |
| `data/pdf_template.json` | tělo PDF šablony (záznam `npc_bridge__PDF_Template__c`, není metadata) |
| `phase2/` | upravená e-mailová šablona (věta o příloze) a nový flow |

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-thankyou --target-org <alias> --test-level RunSpecifiedTests --tests DKD_GiftThankYouServiceTest
sf api request rest /services/data/v64.0/sobjects/npc_bridge__PDF_Template__c --method POST --body @src-crdm-thankyou/data/pdf_template.json --target-org <alias>
sf project deploy start --metadata-dir src-crdm-thankyou/phase2 --target-org <alias>
# permission set přiřadit adminovi a guest userovi, potom:
sf apex run --target-org <alias>   # DKD_GiftThankYouScheduler.scheduleEveryQuarterHour();
```

## Známé podmínky

- Odesílá se **výhradně** z organizační adresy `darci@darujemekrouzky.cz`. Dokud není ověřená, nic neodejde: Apex zapíše chybu do `CRMforNonProfit__Error_Log__c`, dozorčí job čeká a dary zůstávají `To Be Sent`. Po ověření je dozorčí job do 15 minut dobere.
- **Z flow se e-mail neposílá a posílat nesmí.** Flow běží jako guest user site a ten nemůže použít
  organizační adresu – akce Send Email skončí na „Org-Wide Email provided is not valid". Dokud běžela
  synchronně, shodila tím i zápis platby z webhooku (incident 17. 9. 2026, viz
  `src-comgate-npc/PORT_NOTES.md` bod 13). Odesílání patří výhradně do Apexu za platform eventem.
- **Pravidelné dary nemá kdo dobrat.** Dozorčí job filtruje `GiftCommitmentId = null`, takže když
  u pravidelného daru platform event nedorazí nebo odeslání spadne, poděkování už nikdo nepošle.
  Řešením by bylo pole typu `Thank_You_Not_Required__c` (aby job nenabízel každou splátku znovu)
  a rozšíření filtru – zatím **není** implementováno.
- Šablona `DKD_Thank_You_Recurring` musí být **Active**; Apex ji hledá s `IsActive = true`, což
  dřívější lookup ve flow nedělal.
- Před deployem tříd je nutné zrušit naplánované joby `DKD podekovani za dar` a po něm znovu zavolat `scheduleEveryQuarterHour()`.
- Uživatel v `PlatformEventSubscriberConfig` musí být aktivní správce s přiřazeným permission setem. Když se změní, změnit i tady a znovu nasadit.
- `data/pdf_template.json` se POSTuje jen jednou: druhý záznam se stejným názvem by `loadPdfTemplate()` (LIMIT 1) vybíral náhodně.
- Dary vzniklé před `DKD_GiftThankYouScheduler.START` (9. 9. 2026 12:00 UTC) dozorčí job neobesílá.
  U darů z Darujme platí místo toho datum z `Darujme_Thank_You_From__c` – import je zakládá až
  několik dní po daru, takže `CreatedDate` by je pustil i zpětně.
- Custom setting se v orgu nasazením **nevyplní** (hodnoty custom settings nejsou metadata).
  Po deployi je pole prázdné, tedy za dary z Darujme se neděkuje – zapíná se ručně, viz výše.
