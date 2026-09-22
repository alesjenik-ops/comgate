/**
 * Uplatnuje blacklist protiuctu z NNOSettings na dary vznikle parovanim bankovnich vypisu.
 *
 * Na ucet u FIO chodi i platby, ktere nejsou dary: zuctovani platebni brany Comgate
 * a vyplaty z Darujme.cz pres Nadaci VIA. Parovani je pripise zalozniho uctu Default
 * a v CRM z nich udela dary - penize se tim pocitaji dvakrat, protoze jednotlive
 * karetni a Darujme dary uz v CRM jsou.
 *
 * Seznam protiuctu, ze kterych se dary nezakladaji, drzi
 * CRMforNonProfit__NNOSettings__c.Account_Num_Blacklist__c. Zapisuji se cisla uctu
 * oddelena novym radkem, carkou nebo strednikem, s kodem banky i bez nej.
 *
 * Samotne nastaveni parovani nezastavi - FpackTransactionPairingQueueable
 * i EntityPairing v balicku npc_bridge ctou z NNOSettings jen tri vychozi lookupy
 * a blacklist ignoruji. Dar proto vznikne a tahle trida ho hned zahodi. Bankovni
 * transakce zustava, jen z ni neni dar.
 */
public without sharing class DKD_AccountBlacklist {

    private static Set<String> cached;

    /** Cisla uctu z nastaveni, znormalizovana na porovnani. */
    public static Set<String> numbers() {
        if (cached == null) {
            cached = new Set<String>();
            for (CRMforNonProfit__NNOSettings__c settings : [
                    SELECT CRMforNonProfit__Account_Num_Blacklist__c
                    FROM CRMforNonProfit__NNOSettings__c
                    LIMIT 1
            ]) {
                String raw = settings.CRMforNonProfit__Account_Num_Blacklist__c;
                if (String.isBlank(raw)) {
                    continue;
                }
                for (String part : raw.split('[\\r\\n,;]')) {
                    String cleaned = normalize(part);
                    if (String.isNotBlank(cleaned)) {
                        cached.add(cleaned);
                    }
                }
            }
        }
        return cached;
    }

    @TestVisible
    private static String normalize(String accountNumber) {
        return accountNumber == null ? null : accountNumber.trim().replaceAll('\\s', '');
    }

    public static Boolean isBlacklisted(String accountNumber) {
        String cleaned = normalize(accountNumber);
        if (String.isBlank(cleaned)) {
            return false;
        }
        Set<String> blacklist = numbers();
        if (blacklist.contains(cleaned)) {
            return true;
        }
        // do nastaveni jde zapsat i samotne cislo uctu bez lomitka a kodu banky
        Integer slash = cleaned.indexOf('/');
        return slash > 0 && blacklist.contains(cleaned.substring(0, slash));
    }

    /**
     * Zahodi dary, ktere parovani zalozilo z platby na blacklistovanem protiuctu.
     * Vola se z after insert - before insert zapis zrusit neumi a addError by
     * shodil cely upsert davky v balicku.
     */
    public static void discardPairedGifts(List<GiftTransaction> records) {
        if (records == null || numbers().isEmpty()) {
            return;
        }
        List<GiftTransaction> toDiscard = new List<GiftTransaction>();
        for (GiftTransaction gt : records) {
            if (gt.npc_bridge__SourceFpackTransaction__c != null
                    && isBlacklisted(gt.npc_bridge__Source_Account_Number__c)) {
                toDiscard.add(new GiftTransaction(Id = gt.Id));
            }
        }
        if (!toDiscard.isEmpty()) {
            delete toDiscard;
        }
    }

    /**
     * Doveze uklid na darech, ktere vznikly drive, nez se blacklist zavedl.
     * Vraci pocet zahozenych daru, je idempotentni.
     */
    public static Integer discardExisting() {
        List<GiftTransaction> paired = [
                SELECT Id, npc_bridge__SourceFpackTransaction__c, npc_bridge__Source_Account_Number__c
                FROM GiftTransaction
                WHERE npc_bridge__SourceFpackTransaction__c != NULL
                LIMIT 10000
        ];
        List<GiftTransaction> toDiscard = new List<GiftTransaction>();
        for (GiftTransaction gt : paired) {
            if (isBlacklisted(gt.npc_bridge__Source_Account_Number__c)) {
                toDiscard.add(gt);
            }
        }
        if (!toDiscard.isEmpty()) {
            delete toDiscard;
        }
        return toDiscard.size();
    }

    @TestVisible
    private static void resetCache() {
        cached = null;
    }
}
