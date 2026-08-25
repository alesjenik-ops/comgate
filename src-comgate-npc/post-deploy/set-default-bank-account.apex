// Nastaveni vychoziho bankovniho uctu pro stranku s QR kodem (Darujeme krouzky detem).
// Ucet: 2602488698 / 2010 (Fio banka), IBAN CZ19 2010 0000 0026 0248 8698.
//
// Spustte v Developer Console > Debug > Open Execute Anonymous Window.
// Bank_Account__c je DATA, ne metadata - deploy pres Workbench tento zaznam nevytvori.
//
// Odkud se ucet bere: DonationPageController.justCreateRecords() pouzije
// Campaign.Bank_Account__r, a kdyz kampan ucet nastaveny nema, sahne po
// Bank_Account__c s Default__c = TRUE. Z nej se plni cislo uctu, IBAN
// i QR payload (SPD*1.0*ACC:<IBAN>...).
//
// Skript je idempotentni - lze ho spustit opakovane.

String accountNumber = '2602488698/2010';
String iban = 'CZ1920100000002602488698';

// Ostatni ucty odznacit, aby zustal jediny vychozi (query je LIMIT 1, ale porade se hodi).
List<Bank_Account__c> others = [SELECT Id, Default__c FROM Bank_Account__c WHERE Default__c = TRUE];
List<Bank_Account__c> toUpdate = new List<Bank_Account__c>();

Bank_Account__c target;
for (Bank_Account__c ba : others) {
    if (target == null) {
        target = ba;
    } else {
        ba.Default__c = false;
        toUpdate.add(ba);
    }
}

if (target == null) {
    target = new Bank_Account__c();
}

// Pole se nastavuji dynamicky pres put(), protoze Execute Anonymous pri kompilaci
// vynucuje viditelnost poli (FLS) - cerstve nasazena pole ji jeste nemaji.
target.put('Bank_Account_Number__c', accountNumber);
target.put('IBAN__c', iban);
target.put('Default__c', true);
toUpdate.add(target);

upsert toUpdate;

System.debug('Vychozi Bank_Account__c: ' + accountNumber + ' / ' + iban + ' (Id ' + target.Id + ')');

// Pozor: pokud ma kampan vyplnene sve vlastni Campaign.Bank_Account__c, ma prednost
// pred timto vychozim zaznamem. Zkontrolujte:
for (Campaign c : [SELECT Id, Name, Bank_Account__r.Bank_Account_Number__c
                   FROM Campaign WHERE Bank_Account__c != NULL]) {
    System.debug('Kampan s vlastnim uctem: ' + c.Name + ' -> ' + c.Bank_Account__r.Bank_Account_Number__c);
}
