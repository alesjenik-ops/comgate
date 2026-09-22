/**
 * Jedine misto, kde se dar srovnava pri zapisu - plati i pro zapisy managed balicku
 * npc_bridge, kam jinak nevidime, a proto je to trigger, ne uprava integracniho kodu.
 *
 * 1. DKD_PaymentMethodMapper drzi PaymentMethod v jednotnem tvaru "kanal - metoda".
 * 2. DKD_GiftTransactionDates doplni TransactionDate u nezaplacenych prevodu,
 *    bez ktereho je parovani bankovnich vypisu nenajde.
 * 3. DKD_AccountBlacklist zahodi dary z protiuctu, ktere v NNOSettings nejsou
 *    darci (zuctovani Comgate, vyplaty z Darujme pres Nadaci VIA).
 *
 * Poradi je zavazne: datum se rozhoduje podle uz srovnane platebni metody.
 * Blacklist bezi az after insert - before insert zapis zrusit neumi.
 *
 * Na update se platebni metoda pocita jen tehdy, kdyz se zmenila vstupni data,
 * aby pri bezne editaci daru nestoupal pocet SOQL dotazu. Datum zadny dotaz
 * nepotrebuje, takze projde vzdy.
 */
trigger DKD_GiftTransactionRules on GiftTransaction (before insert, before update, after insert) {

    if (Trigger.isAfter) {
        DKD_AccountBlacklist.discardPairedGifts(Trigger.new);
        return;
    }

    List<GiftTransaction> toProcess = new List<GiftTransaction>();

    if (Trigger.isInsert) {
        toProcess = Trigger.new;
    } else {
        for (GiftTransaction gt : Trigger.new) {
            GiftTransaction old = Trigger.oldMap.get(gt.Id);
            if (gt.Payment_Method__c != old.Payment_Method__c
                    || gt.PaymentMethod != old.PaymentMethod
                    || gt.GiftCommitmentId != old.GiftCommitmentId
                    || gt.npc_bridge__Darujme_Transaction__c != old.npc_bridge__Darujme_Transaction__c
                    || gt.npc_bridge__SourceFpackTransaction__c != old.npc_bridge__SourceFpackTransaction__c) {
                toProcess.add(gt);
            }
        }
    }

    DKD_PaymentMethodMapper.apply(toProcess);
    DKD_GiftTransactionDates.apply(Trigger.new);
}
