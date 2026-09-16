# Poděkování za dar s potvrzením (CRDM)

Automatický děkovný e-mail s PDF potvrzením o daru po každém **jednorázovém zaplaceném** daru.
Podle šablon `děkovný dopis individuální dárce jednorázový.docx` a `potvrzení o daru DKD.docx` (9/2026).

## Jak to běží

1. Comgate webhook přepne `GiftTransaction.Status` na `Paid`.
2. Flow `Gift_Transaction_Thank_You_Email` (record-triggered) → pro dar bez `GiftCommitment` a s
   `AcknowledgementStatus != Sent` zavolá Apex `DKD_GiftThankYouService`. Flow běží jako guest user
   site (ten zapsal platbu z webhooku) a ten nemá práva e-mail poslat, proto invocable metoda jen
   **publikuje platform event `DKD_Thank_You_Requested__e`**. Jeho trigger `DKD_ThankYouRequestedTrigger`
   běží díky `PlatformEventSubscriberConfig` jako správce (`crdm@crmproneziskovky.cz`) a zařadí
   Queueable. E-mail tak odchází **během několika sekund po platbě**.
   Pravidelné dary: při první zaplacené platbě závazku pošle e-mail `DKD_Thank_You_Recurring` bez PDF.
   Dary s `PaymentMethod = Darujme` se vynechávají.
3. Apex vygeneruje PDF ze šablony `npc_bridge__PDF_Template__c` „Potvrzeni o daru DKD" přes VF stránku balíčku
   `GiftConfirmationPDF`, vyplní e-mail `DKD_Thank_You_One_Time` (merge pole `{!GiftTransaction.X}`), pošle ho
   z organizační adresy `darci@darujemekrouzky.cz` (jen pokud je ověřená), uloží jako **EmailMessage pod kontakt
   dárce**, PDF uloží jako soubor k transakci a nastaví `AcknowledgementStatus`/`TaxReceiptStatus = Sent`.
4. Dozorčí job `DKD_GiftThankYouScheduler` (každých 15 min, běží jako admin) je pojistka: dobere dary,
   u kterých event nedorazil nebo odeslání spadlo. Stav `Sent` se zapisuje před odesláním – bez rizika duplicit.

## Obsah

| Cesta | Co |
| --- | --- |
| `objects/GiftTransaction.object` | 6 formula polí: oslovení, částka text, rok, jméno/e-mail/adresa dárce pro potvrzení |
| `classes/` | `DKD_GiftThankYouService`, `…Queueable`, `…Scheduler`, test (pokrytí 90–94 %) |
| `objects/DKD_Thank_You_Requested__e.object` | platform event s `Gift_Transaction_Id__c`, publikuje se po commitu |
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

- Odesílá se **výhradně** z organizační adresy `darci@darujemekrouzky.cz`. Dokud není ověřená, nic neodejde: flow zapíše chybu do Error Logu, dozorčí job čeká a dary zůstávají `To Be Sent`. Po ověření je dozorčí job do 15 minut dobere.
- Před deployem tříd je nutné zrušit naplánované joby `DKD podekovani za dar` a po něm znovu zavolat `scheduleEveryQuarterHour()`.
- Uživatel v `PlatformEventSubscriberConfig` musí být aktivní správce s přiřazeným permission setem. Když se změní, změnit i tady a znovu nasadit.
- `data/pdf_template.json` se POSTuje jen jednou: druhý záznam se stejným názvem by `loadPdfTemplate()` (LIMIT 1) vybíral náhodně.
- Dary vzniklé před `DKD_GiftThankYouScheduler.START` (9. 9. 2026 12:00 UTC) dozorčí job neobesílá.
