# Comgate → Nonprofit Cloud port — poznámky

Tento strom (`src-comgate-npc/`) je port Comgate integrace z NPSP (`src-comgate/`) na datový model
Salesforce Nonprofit Cloud. Architektonickým vzorem byla Stripe implementace (`src/`), která už na NPC běží.

## Mapování datového modelu (NPSP → NPC)

| NPSP (src-comgate) | NPC (src-comgate-npc) |
|---|---|
| Contact dárce (dedup dle Email) | Account: PersonAccount (dedup dle PersonEmail) nebo firemní Account (dedup dle `CRMforNonProfit__ICO__c`, kontakt přes `npc_bridge__PrimaryContact__c`) |
| Opportunity (Pledged/Posted/Closed Lost) | GiftTransaction (Status Unpaid/Paid/Failed; stav brány v `Status__c`) |
| npe03__Recurring_Donation__c | GiftCommitment + GiftCommitmentSchedule (`Type='CreateTransactions'`) + GiftDefaultDesignation + první Unpaid GiftTransaction |
| Opportunity.Comgate_* pole | GiftTransaction: `Comgate_Transaction_Id__c`, `Comgate_Variable_Symbol__c` + sdílená `Status__c`, `Status_Reason__c`, `Attempt_Counter__c`, `Last_Attempt_Date__c`, `Payment_Method__c` |
| RD.Comgate_Authorized__c **a** RD.Comgate_Recurring_Authorized__c (dvě pole) | jediné `GiftCommitment.Comgate_Authorized__c` (viz oprava č. 6) |
| RD.Comgate_Initial_Transaction_Id__c | GiftCommitment.Comgate_Initial_Transaction_Id__c |
| Payment_Log__c / Payment_Reference__c lookupy na Opportunity/RD/Contact | lookupy `Gift_Transaction__c` / `Gift_Commitment__c` / `Account__c` |

Front-end: aura formulář `DonationPageForm` (a FieldSet/Item) přepnut z Contact na Account
(atribut `donor`, field sety na Accountu přes `ContactFieldSetsDynamicPicklist` — Account verze ze Stripe orgu,
country picklist z `Account.Country__c` + global value set `Countries`).
Nové design atributy: `receiverName`, `supportEmail` (nahrazují hardcode „Clouderia s.r.o." / e-maily).

## Vědomé opravy oproti originálům

1. **`test` flag** v ComgatePaymentRequestWrapper/ComgateRecurringRequestWrapper: `= runningInASandbox`
   (originál měl invertované `!` → testovací platby v produkci a ostré v sandboxu).
2. **`getCampaignDetails`**: podmínka `campaignId == null || !(campaignId instanceof Id)` — originál měl
   `!= null ||`, takže `Campaign.Comgate_Bank_Account__c` se u jednorázových plateb nikdy nepoužil.
3. **Charge batch, single-record konstruktor**: bind na správnou proměnnou (`:giftTransactionId`) —
   StripeChargePaymentsBatch má v této větvi zastaralý bind `:oppId`, který by za běhu spadl.
4. **Charge batch, vyhodnocení odpovědi**: chyba = `response == null || (code != null && code != 0)`;
   při chybě se zapisuje důvod a počítadlo pokusů, při úspěchu `Status__c='PENDING'` + `Comgate_Transaction_Id__c`
   (potvrzení PAID přijde webhookem). Originál měl podmínku invertovanou a zapisoval „null null".
5. **Webhook, recurring handlery**: nejstarší **Unpaid** GiftTransaction se hledá samostatným dotazem
   s ošetřením prázdného výsledku (originál sahal na `npe03__Donations__r[0]` a padal na ListException).
6. **Sjednocení autorizace**: batch i webhook používají jediné pole `Comgate_Authorized__c`
   (v originálu webhook zapisoval `Comgate_Recurring_Authorized__c`, ale batch filtroval podle
   `Comgate_Authorized__c`, takže nabíjení se nikdy nespustilo bez ručního zásahu).
7. **`fullname`** posílané do Comgate: s mezerou (`FirstName + ' ' + LastName`), u person accountu `donor.Name`.
8. **Payment option switch** přijímá `'bankTransfer'` i `'banktransfer'` (aura posílá camelCase, Stripe org lowercase).
9. **QR payload** bez hardcoded `*MSG:...pro Cesky Cerveny Kriz` řádku.
10. **Label platby** v Comgate: název kampaně, fallback `'Dar'` (originál: hardcoded „Comgate Test Donation").
11. **Plánování cleanup batche** v `finish()`: plánuje se, když job NENÍ naplánován
    (`checkIfAlreadyScheduled` vrací true = nenaplánováno; Stripe originál měl negaci obráceně,
    takže se cleanup nikdy nenaplánoval).
12. **Footer logo** default `DonationPageFooterLogo` (resource `FooterLogoSimple` v žádném retrieve neexistuje).

## Nové artefakty (nikde předtím neexistovaly)

- `ComgateMonthlyCleanupBatch` (+ test) — port StripeMonthlyCleanupBatch: zavře GiftCommitment
  se 3 po sobě splatnými nezaplacenými transakcemi.
- Flows `Gift_Transaction_After_Insert_Comgate` a `Gift_Commitment_After_Insert_Comgate` —
  kopírují `Comgate_Variable_Symbol__c` (AutoNumber) do `npc_bridge__Variable_Symbol__c`
  (gate: `ProcessorReference='Comgate'` resp. `Comgate_Recurring__c=true`).
- Kompletní testovací sada (v NPSP stromu žádné Comgate testy nebyly): ComgateTestFactory, ComgateMockTest,
  ComgateServiceTest, ComgateWebhookTest, ComgateChargePaymentsBatchTest, ComgateMonthlyCleanupBatchTest,
  DonationPageControllerTest, ComgateUtilTest, DonationPageUrlRewriterTest.
- Rekonstruovaná pole na standardních objektech (viz níže).

## Rekonstruovaná pole — POZOR před nasazením do orgu, kde už existují

Soubory `objects/GiftTransaction.object`, `GiftCommitment.object`, `Campaign.object`, `Account.object`
definují pole, jejichž originální definice nebyly v žádném retrieve (retrieve neobsahoval standardní objekty).
Pole `Comgate_*` jsou nová (autoritativní zde). Sdílená pole (`Status__c`, `Status_Reason__c`,
`Attempt_Counter__c`, `Last_Attempt_Date__c`, `Payment_Method__c`, `Country__c`, `Donation_Page_*`)
jsou **rekonstrukce podle použití v kódu** — pokud cílový org tato pole už má (org se Stripe integrací),
před deployem tyto bloky ze souborů odstraňte, nebo je nahraďte definicemi staženými z orgu,
jinak deploy přepíše jejich picklist hodnoty/popisky.

`Comgate_Variable_Symbol__c` je AutoNumber `{0000000000}` — pokud má org vlastní číselnou řadu
variabilních symbolů, upravte formát/startovní číslo před prvním nasazením.

## Co ve stromu záměrně NENÍ (nutno zajistit v cílovém orgu)

- **External Credential `ComgatePayments`** (Basic auth merchant:secret) — named credential
  `ComgatePaymentsNamed` na něj odkazuje; založit ručně v Setup → Named Credentials a vyplnit
  merchant + secret z Comgate portálu.
- **Experience Cloud site** (kompozice stránky v Builderu) — v žádném retrieve není; stránku je nutné
  složit v Experience Builderu (theme layout `DonationPageLayout`, do regionu form `DonationPageForm`,
  sekce `donationPage*Section`), nebo stáhnout `DigitalExperienceBundle` ze zdrojového orgu.
- **CustomSite definice** (doména, guest user, přiřazení `DonationPageUrlRewriter`) — org-specifické.
- **Guest user oprávnění** — guest profil site potřebuje: create Account/Contact/GiftTransaction/
  GiftCommitment/GiftCommitmentSchedule/GiftDefaultDesignation/GiftDesignation/Payment_Reference__c/
  Payment_Log__c, read Campaign/Bank_Account__c, přístup k Apex třídám DonationPageController,
  ContactFieldSetsDynamicPicklist, ResourceReaderController a REST endpointu ComgateWebhook.
- **Naplánování jobů** (Execute Anonymous po deployi):
  `System.schedule('ComgateChargePaymentsBatch', '0 0 8 * * ?', new ComgateChargePaymentsBatch());`
- **Org default Comgate_Settings__c** (Attempt_Limit__c, Attempt_Delay__c, Day_Of_Charging__c).
- **Account field set** pro formulář (např. `DonationPage_Default` s poli FirstName, LastName,
  PersonEmail, Phone, Country__c…) — vybírá se v Builderu design atributem.
- **Webhook URL v Comgate portálu**: `https://<doména-site>/services/apexrest/comgatewebhook`.
- **Multicurrency**: kód zapisuje/čte `CurrencyIsoCode` (Payment_Log__c, GiftTransaction) — cílový org
  musí mít zapnuté více měn (oba zdrojové orgy je mají), jinak Apex nezkompiluje.
- **NPC balíčky**: CRMforNonProfit (Nonprofit Cloud), npc_bridge, frops_flow + org automatizace
  `Coordinate_Gift_Commitment_Processing_Custom` / `Daily_Donor_Gift_Summary` (jsou ve `src/flows/`,
  do tohoto stromu nepatří — nasadit ze `src/`, pokud v cílovém orgu chybí).

## Vědomě ponechané chování

- Webhook vrací vždy HTTP 200 (i při neúspěšné verifikaci) — záměr, Comgate pak neretryuje donekonečna.
- Verifikace webhooku = zpětné ověření stavu přes GET payment status (payload `secret` se nevaliduje) —
  stejné jako originál.
- Honeypot `privacyAgreement` (skrytý checkbox, Apex při true vyhodí výjimku).
- GTM/JENTIS analytické eventy ve formuláři ponechány beze změny.
- Viditelné texty thank-you kroku v `DonationPageForm.cmp` (odkazy Facebook/Instagram „CLOUDERIA")
  zůstaly z originálu — upravte podle organizace; první řádek jde přes design atribut `thankYouLabel`,
  resp. `Campaign.Donation_Page_Thank_You_Text__c`.
- Kurzy měn pro přepočet nabízených částek jsou hardcoded v `DonationPageForm.cmp` (`currencies`).
