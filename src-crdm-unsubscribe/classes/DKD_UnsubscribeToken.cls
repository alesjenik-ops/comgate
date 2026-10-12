// Tokeny do odhlasovaciho odkazu. Token je nahodny (128 bitu), takze z odkazu nejde odvodit
// odkaz jineho darce, jako by to slo u Id kontaktu.
public without sharing class DKD_UnsubscribeToken {

    public static String generate() {
        return EncodingUtil.convertToHex(Crypto.generateAesKey(128));
    }

    // Contact before insert - jen kde token jeste neni
    public static void fillContacts(List<Contact> contacts) {
        for (Contact c : contacts) {
            if (String.isBlank(c.DKD_Unsubscribe_Token__c)) c.DKD_Unsubscribe_Token__c = generate();
        }
    }

    // Account before insert - osobni ucet nese pole kontaktu jako __pc
    public static void fillPersonAccounts(List<Account> accounts) {
        Set<Id> personTypes = new Set<Id>();
        for (RecordTypeInfo rti : Schema.SObjectType.Account.getRecordTypeInfos()) {
            if (rti.getDeveloperName() == 'PersonAccount') personTypes.add(rti.getRecordTypeId());
        }
        for (Account a : accounts) {
            if (!personTypes.contains(a.RecordTypeId)) continue;
            if (String.isBlank(a.DKD_Unsubscribe_Token__pc)) a.DKD_Unsubscribe_Token__pc = generate();
        }
    }
}
