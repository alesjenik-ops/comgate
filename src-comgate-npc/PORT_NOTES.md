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

Front-end: aura formulář `DonationPageForm` (a FieldSet/Item/Layout/Header/Footer) je založen na
**reálné NPC verzi ze Stripe orgu** (doplňkový retrieve) — tedy včetně přepínače fyzická/právnická osoba,
výběru kampaně (message channel `donationPageCampaignSelection`), field setů na Accountu, country picklistu
z `Account.Country__c` a českých textů. Jediná náhrada: krok platby — místo `stripePaymentForm`
(embedded Stripe Checkout) se volá `createComgatePayment` a redirect URL se renderuje v
`comgatePaymentForm` iframu (`allow="payment"`); návrat z brány řeší postMessage `onSuccessPage`
z vnořené stránky (převzato z Comgate originálu). PayPal volba odstraněna (Comgate ji nenabízí).
Design atributy `receiverName`/`supportEmail` (výchozí hodnoty ČČK) nahrazují hardcoded texty.
`getReferenceId` vrací klíče `shopperReference`/`paymentReference` (konvence reálného formuláře).

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
12. **Footer logo** default `DonationPageFooterLogo` — odpovídá reálné NPC verzi footeru
    (`FooterLogoSimple` z Comgate orgu je k dispozici ve `src-comgate/staticresources/`).

## Nové artefakty (nikde předtím neexistovaly)

- `ComgateMonthlyCleanupBatch` (+ test) — port StripeMonthlyCleanupBatch: zavře GiftCommitment
  se 3 po sobě splatnými nezaplacenými transakcemi.
- Flows `Gift_Transaction_After_Insert_Comgate` a `Gift_Commitment_After_Insert_Comgate` —
  kopírují `Comgate_Variable_Symbol__c` (AutoNumber) do `npc_bridge__Variable_Symbol__c`
  (gate: `ProcessorReference='Comgate'` resp. `Comgate_Recurring__c=true`).
- Kompletní testovací sada (v NPSP stromu žádné Comgate testy nebyly): ComgateTestFactory, ComgateMockTest,
  ComgateServiceTest, ComgateWebhookTest, ComgateChargePaymentsBatchTest, ComgateMonthlyCleanupBatchTest,
  DonationPageControllerTest, ComgateUtilTest, DonationPageUrlRewriterTest.
- Pole `Comgate_*` na standardních objektech GiftTransaction/GiftCommitment/Campaign (viz níže).

## Pole na standardních objektech — převzaté reálné definice

Po doplňkových retrievech z obou orgů jsou definice ve `objects/` převzaté z reálných orgů
(už nejde o rekonstrukce):

- Sdílená pole (`Status__c`, `Status_Reason__c`, `Attempt_Counter__c`, `Last_Attempt_Date__c`,
  `Payment_Method__c`, `Country__c`, `Receive_One_Time_POD__c`, `Tax_identification_number__c`,
  `Donation_Page_*`, `Campaign.Bank_Account__c`) = přesné definice ze Stripe/NPC orgu, včetně
  field setu **`Account.DonationPageFieldSet`** (Receive_One_Time_POD__c, FirstName, LastName,
  PersonEmail, PersonMobilePhone, PersonMailing*).
- `GiftTransaction.Status__c` je restricted picklist — port rozšiřuje původních šest hodnot
  (CAPTURED/PENDING/ERROR/CHARGEBACK/CANCELLATION/REFUND) o Comgate stavy **PAID/AUTHORIZED/CANCELLED**;
  deploy hodnoty sloučí.
- `Payment_Method__c` (GiftTransaction i GiftCommitment) je vázané na global value set
  **`Payment_Method`** — port jej rozšiřuje o hodnoty `Credit Card`, `Online Bank`, `Google Pay`,
  `Apple Pay` (vrací je ComgateUtil.convertComgatePaymentMethod).
- `Campaign.Comgate_Bank_Account__c` je **restricted picklist** (převzato z Comgate orgu, hodnota `none`) —
  po nasazení doplňte do picklistu kódy účtů z Comgate portálu.
- `Comgate_Variable_Symbol__c` je AutoNumber s prefixovou řadou podle vzoru Stripe polí
  (Stripe: GT `1{000000000}`, GC `8{000000000}`): Comgate používá **GT `2{000000000}`,
  GC `9{000000000}`**, aby se řady VS nepřekrývaly. Případně upravte před prvním nasazením.

## Co je nově součástí stromu (z doplňkových retrievů)

- `externalCredentials/ComgatePayments.externalCredential` — Basic auth konfigurace (bez secretu);
  po deployi vyplňte v Setup → Named Credentials principal `Credentials` (merchant + secret z Comgate portálu).
- `permissionsets/Comgate_Integration.permissionset` — NPC verze permission setu z Comgate orgu
  (přístup k ComgateWebhook/DonationPageController/ResourceReaderController, Payment_Log__c,
  Payment_Reference__c, external credential principal). Přiřaďte guest userovi site a integračnímu uživateli.
- `messageChannels/donationPageCampaignSelection.messageChannel` + LWC `donationPageCampaignDetail`,
  `loaderRoller` — výběr kampaně a detail kampaně na stránce (reálná NPC kompozice).
- Reálný `FieldSetWrapper` (country picklist přes `Account.PersonMailingCountry` → hodnoty `Account.Country__c`).
- `paymentDetailsPage` LWC v české NPC verzi.

## Co ve stromu záměrně NENÍ (nutno zajistit v cílovém orgu)

- **Experience Cloud site** (kompozice stránky v Builderu) — `DigitalExperienceBundle` nevrátil ani jeden
  org (starší typ site bez Builder bundle); stránku je nutné složit v Experience Builderu
  (theme layout `DonationPageLayout`, do regionu form `DonationPageForm`, sekce `donationPage*Section`,
  `donationPageCampaignDetail`).
- **CustomSite definice** (doména, guest user, přiřazení `DonationPageUrlRewriter`) — org-specifické.
  Guest profil „Donation Page Profile" z obou orgů je pro referenci ve `src/profiles/` a
  `src-comgate/profiles/`; oprávnění pokrývá permission set `Comgate_Integration` + create na
  Account/Contact/GiftTransaction/GiftCommitment/GiftCommitmentSchedule/GiftDefaultDesignation/
  GiftDesignation, read Campaign/Bank_Account__c.
- **Naplánování jobů** (Execute Anonymous po deployi):
  `System.schedule('ComgateChargePaymentsBatch', '0 0 8 * * ?', new ComgateChargePaymentsBatch());`
- **Org default Comgate_Settings__c** (Attempt_Limit__c, Attempt_Delay__c, Day_Of_Charging__c).
- **Account field set** pro formulář (např. `DonationPage_Default` s poli FirstName, LastName,
  PersonEmail, Phone, Country__c…) — vybírá se v Builderu design atributem.
- **Webhook URL v Comgate portálu**: `https://<doména-site>/services/apexrest/comgatewebhook`.
- **AppleVerification static resource**: obsah je vázaný na doménu — pro novou doménu nahrajte
  domain-association soubor, který pro Apple Pay vydá Comgate (soubor v repu je z původní domény).
- **Multicurrency**: kód zapisuje/čte `CurrencyIsoCode` (Payment_Log__c, GiftTransaction) — cílový org
  musí mít zapnuté více měn (oba zdrojové orgy je mají), jinak Apex nezkompiluje.
- **NPC balíčky**: CRMforNonProfit (Nonprofit Cloud), npc_bridge, frops_flow + org automatizace
  `Coordinate_Gift_Commitment_Processing_Custom` / `Daily_Donor_Gift_Summary` (jsou ve `src/flows/`,
  do tohoto stromu nepatří — nasadit ze `src/`, pokud v cílovém orgu chybí).

## Vědomě ponechané chování

- Webhook vrací vždy HTTP 200 (i při neúspěšné verifikaci) — záměr, Comgate pak neretryuje donekonečna.
- Verifikace webhooku = zpětné ověření stavu přes GET payment status (payload `secret` se nevaliduje) —
  stejné jako originál.
- Server stále odmítá `privacyAgreement == true` (honeypot); reálný NPC formulář ale skrytý checkbox
  nemá, takže kontrola je jen pojistka pro přímá volání API.
- GTM/JENTIS analytické eventy ve formuláři ponechány beze změny.
- Thank-you texty: první řádek přes design atribut `thankYouLabel`; text z
  `Campaign.Donation_Page_Thank_You_Text__c` má přednost (formulář ho načítá při výběru kampaně);
  fallback odstavce v `DonationPageForm.cmp` odkazují na cervenykriz.eu (převzato z reálného formuláře).
- Formulář je fixně v CZK (převzato z reálné NPC verze — výběr měny je disabled).

## Branding — Darujeme kroužky dětem (ČRDM)

Grafika a obsah komponent upraveny podle DKD Brand Manuálu (10/2025):

- **Barvy** (v `DonationPageCss` + CSS aura komponent): primární Dark Plum `#362031`
  (odstín 700 `#4f3549`), akcent/CTA Cotton Candy `#fa95c2` (hover `#f76fae`), pozadí
  Soft Linen `#f3f0eb` (odstín 300 `#e4e3df`), doplňkové Lilac Haze `#c0baec` a Skymint
  `#75d4e6`. Chybové stavy záměrně zůstaly červené (`#ec3039`) kvůli srozumitelnosti.
- **Typografie**: Fira Sans (Regular 400, Medium 500, Bold 700, ExtraBold 800; latin +
  latin-ext) — bundlovaná ve static resource **`DonationPageFonts`** (woff2, @font-face
  v `DonationPageCss`), takže funguje bez CSP výjimek. Nadpisy ExtraBold dle manuálu.
- **Texty**: hlavička formuláře „Darujeme kroužky dětem", poděkování a marketingový souhlas
  odkazují na darujemekrouzky.cz; příjemce plateb „Česká rada dětí a mládeže"; footer
  s odkazy na darujemekrouzky.cz a crdm.cz. `supportEmail` je prázdný default — doplňte
  v Builderu (chybová hláška se bez něj zobrazí bez kontaktu).
- **Zbývá dodat obrazové assety** (nejsou v brand manuálu jako exporty — jsou na Sharepointu,
  viz kapitola 5 „Kam dál"): nahraďte obsah static resources `DonationPageHeaderLogo`,
  `DonationPageFooterLogo`, `DonationPageHeaderImage`, `DonationPageBackground`,
  `DonationPageFavicon` a galerii v `DonationPageImages` DKD verzemi (aktuálně obsahují
  grafiku ČČK). Footer ukazuje kontakty jen obecně (web + provozovatel) — telefon/adresu
  případně doplňte přímo v `DonationPageFooter.cmp`.
- **Fotky už vyměněné**: `DonationPageHeaderImage` = holčička u piana (převzato ze záhlaví
  darujemekrouzky.cz/obecne-darcovstvi, oříznuto na poměr 2,56:1 kvůli `background-size: cover`),
  `DonationPageCampaignPhoto` = původní fotka tří dětí ze záhlaví (nahradila fotku
  s paní Pavlovou). `DonationPageHeaderLogo`/`FooterLogo` už DKD logo (negativ) jsou.

## Děkovné dopisy po zaplacení daru

Rozesílá flow **`Gift_Transaction_Thank_You_Email`** (GiftTransaction, after save,
create i update). Vstupní podmínka: `Status = 'Paid'` **a** `Thank_You_Email_Sent__c = false`.
Vlastní logika běží na cestě **Run Asynchronously** (`AsyncAfterCommit`) — stejně jako
`Gift_Transaction_After_Update` ve Stripe stromu. Důvod: odeslání e-mailu se tím oddělí
od transakce Comgate webhooku, takže chyba v e-mailu nemůže zrušit zápis „zaplaceno".

Větvení:

| Situace | Šablona |
|---|---|
| GiftTransaction **bez** GiftCommitment | `DKD_Thank_You_One_Time` („Děkujeme za váš dar") |
| **první** zaplacená transakce pod GiftCommitment | `DKD_Thank_You_Recurring` („Děkujeme, že v tom jedete s námi") |
| další pravidelné platby | žádný e-mail, jen se nastaví příznak |

„První transakce" se nepozná počítáním transakcí, ale příznakem
`GiftCommitment.Thank_You_Email_Sent__c` — je to idempotentní, takže ani opakovaný
webhook nebo ruční překlopení stavu dopis neposlou dvakrát.
`GiftTransaction.Thank_You_Email_Sent__c` drží totéž na úrovni transakce a zároveň
brání rekurzi (je součástí vstupní podmínky flow).

Merge pole se berou z GiftTransaction přes `relatedRecordId`, ne z příjemce —
formule `Thank_You_Donor_Name__c` (`Donor.FirstName`, fallback `Donor.Name`) a
`Thank_You_Amount__c` (`TEXT(ROUND(OriginalAmount, 0))`, aby v dopise bylo „500 Kč"
a ne „500.00"). Příjemce je `Donor.PersonContactId`, u firemního účtu
`Donor.npc_bridge__PrimaryContact__c`.

Šablony jsou **Classic HTML** (`type custom`, bez `uiType`) ve složce
`email/DKD_Dekovne_Dopisy/`, merge syntaxe `{!GiftTransaction.Pole__c}` proti whatId.
Lightning verze (`uiType SFX` + `{{{Record.Pole__c}}}`) nasadit nešla: `EmailFolder`
v Metadata API zakládá klasickou složku a SFX šablona do ní nepatří — deploy to hlásí
jako `Cannot find folder:<název>`, přestože složku `SELECT ... FROM Folder` vrací
(ověřeno na `DKD_Dekovne_Dopisy`, Id 00lTe000000V7rdIAC). Logo DKD se do e-mailu tahá z veřejné URL static
resource `DonationPageHeaderLogo` — při změně domény site je potřeba přepsat `src`
v obou `.email` souborech.

**Předpoklad nasazení:** ověřená Org-Wide Email Address `info@darujemekrouzky.cz`.
Bez ní flow doběhne, ale nic neodešle (viz `deploy/README.md`).

**Pozor při nasazování:** složka `DKD_Dekovne_Dopisy` a šablony v ní musí jít ve dvou
samostatných deployích. Metadata API nezaručuje pořadí a šablony se zpracují dřív
než složka — deploy pak spadne na `Cannot find folder:DKD_Dekovne_Dopisy`. Proto jsou
v `deploy/` dva ZIPy. Ze stejného důvodu `Update Records` nad výsledkem `Get Records`
nesmí kombinovat `inputReference` s `inputAssignments` (na `$Record` to Salesforce
povoluje, na proměnnou z Get Records ne) — `Mark_Commitment_Sent` proto hledá
GiftCommitment přes filtr na `Id`, ne přes uloženou proměnnou.

## Thank you page — plný redirect

`DonationPageForm` (design atribut **Thank You Page URL**) i `donationPageCommunity`
(`@api thankYouPageUrl`) mají výchozí hodnotu `https://www.darujemekrouzky.cz/dekujeme/`.
Když je vyplněná, po úspěšné platbě se místo děkovné sekce provede redirect
přes `window.top.location.href` (fallback `window.location.href`) — `top`, aby se
prohlížeč dostal ven z iframu platební brány. Děkovná sekce se nastaví ještě před
redirectem, takže při odmítnuté navigaci zůstane původní chování. Prázdná hodnota =
dárce zůstane na formuláři.

Platí pro oba návraty z brány: top-level návrat s `?status=success` i postMessage
`onSuccessPage` z vnořené stránky.
