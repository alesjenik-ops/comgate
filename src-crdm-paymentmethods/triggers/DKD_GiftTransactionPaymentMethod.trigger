/**
 * Drzi GiftTransaction.PaymentMethod v jednotnem tvaru "kanal - metoda".
 *
 * Bezi i nad zapisy z managed balicku npc_bridge (Darujme, parovani FIO), kam
 * jinak nevidime - proto trigger, ne uprava integracniho kodu.
 * Na update se pocita jen tehdy, kdyz se zmenila vstupni data, aby nestoupal
 * pocet SOQL dotazu pri bezne editaci daru.
 */
trigger DKD_GiftTransactionPaymentMethod on GiftTransaction (before insert, before update) {

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
}
