# Newsletter ve výchozím stavu zaškrtnutý

Pole `CRMforNonProfit__Newsletter__c` (Contact) / `__pc` (osobní účet) je z balíčku Core
a jeho výchozí hodnotu v CRDM orgu změnit nejde (`Cannot modify managed object`).
Místo toho dvě before-save flow při založení záznamu nastaví Newsletter = true:

| Flow | Spouští se |
| --- | --- |
| `DKD_Contact_Newsletter_Default` | nový Contact (kontakty firem) |
| `DKD_Person_Account_Newsletter_Default` | nový Account s `IsPersonAccount = true` (flow na Contact se pro osobní účty nespouští) |

Flow přepíše i výslovné `false` při založení (např. import). Odhlášení přes odkaz
v e-mailu mění existující záznam, takže na něj flow nemá vliv.

Nasazení do produkce vytvoří flow jako Draft – po nasazení je potřeba je aktivovat.
