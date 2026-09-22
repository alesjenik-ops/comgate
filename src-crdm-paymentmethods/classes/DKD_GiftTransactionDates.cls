/**
 * Doplnuje TransactionDate u nezaplacenych daru, ktere dorazi bankovnim prevodem.
 *
 * Darovaci formular ani standardni NPC flow u nezaplaceneho daru TransactionDate
 * neplni - je to datum prijeti penez, a ty jeste nedorazily. Vyplnena je jen
 * splatnost (TransactionDueDate).
 *
 * Parovani bankovnich vypisu v balicku npc_bridge ale kandidaty hleda prave podle
 * TransactionDate (FpackTransactionPairingQueueable, radky 112-114):
 *
 *     Status = 'Unpaid' AND
 *     TransactionDate >= :minOppDate AND
 *     TransactionDate <= :maxOppDate AND
 *     DonorId IN :accountIds
 *
 * Prazdne datum teto podmince nikdy nevyhovi, takze dar z formulare parovani
 * neuvidi a misto oznaceni za zaplaceny zalozi druhy. Takhle vzniklo deset
 * duplicitnich daru za 16 800 Kc.
 *
 * Dokud dar neni zaplaceny, je TransactionDate jen ocekavane datum platby - shodne
 * se splatnosti. Jakmile platba dorazi, prepise ho parovani skutecnym datumem
 * z vypisu (FpackTransactionPairingQueueable radek 174) nebo Comgate webhook
 * (ComgateWebhook radek 242).
 *
 * Plni se jen u prevodu. Karetni platby vyresi webhook behem nekolika minut
 * a parovani vypisu do nich nema co sahat.
 */
public without sharing class DKD_GiftTransactionDates {

    /** Metody, u kterych darce plati sam ze sveho uctu - platbu tedy hlasi az vypis. */
    private static final Set<String> BANK_TRANSFER_METHODS = new Set<String>{
            'Bankovní převod', 'Comgate - Převod', 'Bank Transfer'
    };

    public static void apply(List<GiftTransaction> records) {
        if (records == null) {
            return;
        }
        for (GiftTransaction gt : records) {
            if (needsExpectedDate(gt)) {
                gt.TransactionDate = gt.TransactionDueDate;
            }
        }
    }

    @TestVisible
    private static Boolean needsExpectedDate(GiftTransaction gt) {
        return gt.TransactionDate == null
                && gt.TransactionDueDate != null
                && gt.Status == 'Unpaid'
                && BANK_TRANSFER_METHODS.contains(gt.PaymentMethod);
    }

    /**
     * Doplni datum na uz existujicich nezaplacenych darech, aby je parovani naslo,
     * az platba dorazi. Vraci pocet zmenenych zaznamu, je idempotentni.
     */
    public static Integer backfill() {
        List<GiftTransaction> records = [
                SELECT Id, Status, PaymentMethod, TransactionDate, TransactionDueDate
                FROM GiftTransaction
                WHERE Status = 'Unpaid'
                AND TransactionDate = NULL
                AND TransactionDueDate != NULL
                AND PaymentMethod IN :BANK_TRANSFER_METHODS
                LIMIT 10000
        ];
        if (records.isEmpty()) {
            return 0;
        }
        apply(records);
        update records;
        return records.size();
    }
}
