# Deploy: děkovné dopisy, thank-you redirect, nové fotky

Balíčky obsahují jen to, co se touto změnou mění — není to nasazení celého stromu
`src-comgate-npc/`.

Nasazuje se **nadvakrát**:

| # | ZIP | Obsah |
|---|---|---|
| 1 | `thank-you-letters-1-base.zip` | vše včetně **složky** DKD Thank You |
| 2 | `thank-you-letters-2-templates.zip` | samotné **šablony** dopisů |

Složka a její šablony nesmí jít v jednom deployi — Metadata API nezaručuje pořadí
a šablony se zpracují dřív než složka, což skončí chybou
`Cannot find folder:DKD_Thank_You`.

Přebuildit ze zdrojů: `./deploy/build-thank-you-letters.sh`

## Co se nasazuje

| Metadata | Co přibylo / co se změnilo |
|---|---|
| `EmailTemplate` DKD Thank You | dvě šablony děkovného dopisu (jednorázový / pravidelný dar) |
| `Flow` Gift_Transaction_Thank_You_Email | rozesílá dopisy po zaplacení daru |
| `GiftTransaction` | pole `Thank_You_Email_Sent__c`, `Thank_You_Donor_Name__c`, `Thank_You_Amount__c` |
| `GiftCommitment` | pole `Thank_You_Email_Sent__c` |
| `DonationPageForm` (aura), `donationPageCommunity` (LWC) | parametr **Thank You Page URL** + plný redirect |
| `DonationPageHeader` (aura) | cache-buster `?v2` u fotky v záhlaví |
| `DonationPageController` | bezpečný fallback, když v orgu není výchozí `Bank_Account__c` |
| `StaticResource` DonationPageHeaderImage, DonationPageCampaignPhoto | vyměněné fotky |

## Nasazení přes Workbench

<https://workbench.developerforce.com> → přihlásit do cílového orgu → **migration → Deploy**

### Krok 1 — `thank-you-letters-1-base.zip`

1. Zaškrtnout **Rollback On Error** a **Single Package**
2. Test Level:
   - sandbox → `NoTestRun` (rychlé) nebo `RunLocalTests`
   - **produkce → `RunSpecifiedTests`** a do seznamu `DonationPageControllerTest`
     (balíček mění Apex, produkce vyžaduje testy)
3. **Next → Deploy**
4. Počkat, až *Metadata API Process Status* ukáže `Status: Succeeded`

### Krok 2 — `thank-you-letters-2-templates.zip`

Až po úspěšném kroku 1, jinak složka neexistuje a deploy spadne.

1. Zaškrtnout **Rollback On Error** a **Single Package**
2. Test Level `NoTestRun` (šablony Apex nemění)
3. **Next → Deploy**

## Po nasazení — bez tohoto se dopisy neodešlou

### 1. Org-Wide Email Address (povinné)

Flow hledá odesílatele podle adresy **`info@darujemekrouzky.cz`**.
Setup → *Organization-Wide Addresses* → adresa musí existovat a být **ověřená** (Verified).

Pokud adresa chybí, flow doběhne bez chyby, ale **nic neodešle** a
`Thank_You_Email_Sent__c` zůstane nezaškrtnuté. Jinou adresu nastavíte
v elementu `Get Org Wide Address` ve flow.

### 2. Bankovní účet pro QR kód

Spusťte v Developer Console → *Execute Anonymous*:
`src-comgate-npc/post-deploy/set-default-bank-account.apex`

Nastaví výchozí `Bank_Account__c` na **2602488698 / 2010**,
IBAN **CZ19 2010 0000 0026 0248 8698** (QR payload `SPD*1.0*ACC:<IBAN>`)
a napojí na něj kampaň darovací stránky **701Te00000gDlc7IAC**.

`Bank_Account__c` je *data*, ne metadata — deploy tenhle záznam nevytvoří.
`Campaign.Bank_Account__c` má přednost před výchozím záznamem, proto skript
kampaň přenastavuje výslovně; ostatní kampaně s vlastním účtem jen vypíše
do debug logu, ať je vidět, co dál používá jiný účet.

### 3. Logo v e-mailech

Šablony načítají logo z veřejné URL static resource:

```
https://czechcouncilofchildrenandyouth.my.site.com/donations/sfsites/c/resource/DonationPageHeaderLogo
```

Pokud má site jinou doménu, přepište `src` v obou `.email` souborech.
Ověřte, že se obrázek načte v anonymním okně (guest přístup).

### 4. Thank You Page URL

Experience Builder → komponenta donation formuláře → **Thank You Page URL**.
Výchozí hodnota je `https://www.darujemekrouzky.cz/dekujeme/`.
Prázdná hodnota = dárce zůstane na formuláři a uvidí děkovnou sekci jako dosud.

### 5. Field-Level Security

Nová pole `Thank_You_*` zpřístupněte profilům fundraisingu
(Setup → Object Manager → Gift Transaction / Gift Commitment → Fields).
Guest user je nepotřebuje — flow běží v system contextu.

## Kontrola provozu

Dary, které čekají na dopis (nebo se u nich odeslání nepovedlo):

```sql
SELECT Id, Name, Status, OriginalAmount, GiftCommitmentId, CreatedDate
FROM GiftTransaction
WHERE Status = 'Paid' AND Thank_You_Email_Sent__c = false
ORDER BY CreatedDate DESC
```

Prázdný výsledek = všechno odesláno. Neprázdný a stárnoucí = zkontrolujte bod 1.

Odeslané dopisy jsou vidět jako aktivita na dárci (flow posílá `logEmailOnSend`),
případně v Setup → *Email Log Files*.
