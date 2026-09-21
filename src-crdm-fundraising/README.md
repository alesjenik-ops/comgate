# Fundraising Dashboard (CRDM) – doplněné komponenty

Dashboard `NSK Dashboardy/Fundraising Dashboard` je vložený na výchozí Home Page.
Tahle složka drží dvě komponenty, které k němu přibyly, a reporty pod nimi.

| Komponenta | Report | Co ukazuje |
| --- | --- | --- |
| Dary po měsících dle platební metody | `Dary_po_mesicich_dle_metody` | Zaplacené dary letos, sloupec na měsíc, ve sloupci rozdělení podle platební metody |
| Nezaplacené dary dle metody (dle splatnosti) | `Nezaplacene_dary_dle_metody` | Dary bez stavu *Paid* letos, po měsíci splatnosti, rozdělené podle metody |

Oba reporty jsou matice nad report typem `Gift_Transaction__c`: dolů měsíc, napříč
platební metoda, hodnota součet `CurrentAmount`. Komponenty jsou `ColumnStacked`
s `autoselectColumnsFromReport` = true; s ručně zadaným `chartSummary` a
`groupingColumn` deploy skončí chybou *not compatible with the autoselectColumnsFromReport mode*.

## Proč nezaplacené jdou podle data splatnosti

`TransactionDate` se plní až při zaplacení – u všech 101 nezaplacených darů v orgu
je prázdné, zatímco `TransactionDueDate` je vyplněné u všech. Report proto
seskupuje i filtruje na období podle splatnosti, jinak by spadly všechny do „-".

Filtr je `Status != Paid`, takže kromě *Unpaid* zahrnuje i *Failed* (dnes 21 darů)
a případné další stavy mimo zaplaceno.

## Nasazení

```bash
sf project deploy start --metadata-dir src-crdm-fundraising --target-org <alias>
```
