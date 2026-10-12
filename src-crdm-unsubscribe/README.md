# Odhlášení z newsletteru (CRDM)

Odkaz na odhlášení je v patičce všech e-mailů DKD. Kliknutím dárce otevře stránku na
`https://darci.darujemekrouzky.cz/services/apexrest/odhlaseni?t=<token>` a odhlášení potvrdí
tlačítkem. Pak se:

- pole **Newsletter** (`CRMforNonProfit__Newsletter__c`, u osobního účtu `…__pc`) nastaví na false,
- založí uzavřená **aktivita** (Task) „Odhlášení z newsletteru“ u kontaktu, vlastník = vlastník kontaktu.

Samotné otevření odkazu nikoho neodhlásí. Odkazy v e-mailech otevírá i antispam (Outlook Safe Links,
Gmail), proto odhlašuje až POST z tlačítka.

## Části

| Komponenta | Účel |
| --- | --- |
| `Contact.DKD_Unsubscribe_Token__c` | náhodný token (32 hex, unique), aby z odkazu nešlo odvodit odkaz jiného dárce |
| `GiftTransaction.DKD_Unsubscribe_Token__c` | vzorec – token dárce (osobní kontakt / primární kontakt firmy) pro děkovné dopisy |
| `DKD_ContactUnsubscribeToken`, `DKD_AccountUnsubscribeToken` | triggery: token novým kontaktům a osobním účtům |
| `DKD_UnsubscribeResource` | Apex REST `/odhlaseni`, běží jako guest user site, bez sdílení |
| `DKD_Unsubscribe_Guest` | permission set – přístup guest usera k třídě; přiřazen guest userovi Donation Page |

Stávajícím kontaktům byly tokeny doplněny jednorázově 12. 10. 2026 (1 379 kontaktů).

## Odkaz v šablonách

| Šablona | Merge pole |
| --- | --- |
| Lightning (newslettery) | `…/odhlaseni?t={{{Recipient.DKD_Unsubscribe_Token__c}}}` |
| Děkovné dopisy (classic, `DKD_GiftThankYouService`) | `…/odhlaseni?t={!GiftTransaction.DKD_Unsubscribe_Token__c}` |

Doplněno do: DKD Děkovný dopis – jednorázový i pravidelný, Newsletter DKD – Jeden klik (10/2026),
Info Jeden klik – první týden (10/2026). **Novou šablonu** je potřeba doplnit ručně stejným odkazem.
Šablonu „Newsletter 9/2026“ (drag-and-drop builder) API upravit nedovolí – odkaz jde vložit jen v builderu.

Odhlášení neodebírá dárce z kampaní. Před rozesláním z kampaně je potřeba vyřadit členy s Newsletter = false.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-unsubscribe --target-org <alias> \
  --test-level RunSpecifiedTests --tests DKD_UnsubscribeResourceTest
# permission set DKD_Unsubscribe_Guest priradit guest userovi site
```
