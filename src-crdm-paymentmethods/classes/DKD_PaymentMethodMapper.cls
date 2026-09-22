/**
 * Prevadi platebni metodu daru na jednotny tvar "kanal - metoda".
 *
 * Kazdy kanal zapisuje do GiftTransaction.PaymentMethod neco jineho a nektere
 * zapisy prichazeji z managed balicku, kam nevidime. Trida je proto jedine misto,
 * kde se rozhoduje, jaka hodnota v poli nakonec zustane.
 *
 * Comgate  -> 'Comgate - <metoda>'   podle Payment_Method__c (surova hodnota z brany)
 * Darujme  -> 'Darujme - <metoda>'   podle Darujme Pledge.Payment_Method__c
 * FIO      -> 'Bankovní převod'      dar vznikl parovanim bankovniho vypisu
 */
public without sharing class DKD_PaymentMethodMapper {

    public static final String FIO = 'Bankovní převod';

    /** Stare hodnoty, ktere jednotny tvar nahrazuje. */
    private static final Set<String> LEGACY = new Set<String>{
            'Unknown', 'Credit Card', 'Bank Transfer', 'Bankovní převod',
            'Darujme', 'Online Bank', 'Comgate - Ostatní', 'Darujme - Ostatní'
    };

    /************** Mapovani surovych hodnot **************/

    /** Metoda tak, jak ji hlasi Comgate (CARD_CZ_COMGATE, GPAY, TRANSFER, ...). */
    public static String comgateMethod(String raw) {
        if (String.isBlank(raw)) {
            return null;
        }
        String r = raw.toUpperCase();
        // 'BANK TRANSFER' musi jit pred prefixem 'BANK', jinak by spadlo na bankovni tlacitko
        if (r == 'TRANSFER' || r == 'BANK TRANSFER') {
            return 'Comgate - Převod';
        }
        if (r.startsWith('CARD') || r == 'CREDITCARD' || r == 'CREDIT CARD') {
            return 'Comgate - Karta';
        }
        if (r.startsWith('BANK') || r == 'ONLINE BANK') {
            return 'Comgate - Bankovní tlačítko';
        }
        if (r == 'GPAY' || r == 'GOOGLE PAY') {
            return 'Comgate - Google Pay';
        }
        if (r == 'APPLEPAY' || r == 'APPLE PAY') {
            return 'Comgate - Apple Pay';
        }
        if (r.startsWith('PAYPAL')) {
            return 'Comgate - PayPal';
        }
        return 'Comgate - Ostatní';
    }

    /** Metoda tak, jak ji hlasi Darujme.cz na Pledge. */
    public static String darujmeMethod(String raw) {
        if (String.isBlank(raw)) {
            return 'Darujme - Ostatní';
        }
        switch on raw {
            when 'gp_webpay_charge' {
                return 'Darujme - Karta';
            }
            when 'funds_transfer' {
                return 'Darujme - Převod';
            }
            when 'payu_transfer' {
                return 'Darujme - Bankovní tlačítko';
            }
            when 'csas_permanent_payment' {
                return 'Darujme - Trvalý příkaz';
            }
        }
        return 'Darujme - Ostatní';
    }

    /************** Vstupni bod pro trigger i pro migraci **************/

    /**
     * Doplni PaymentMethod tam, kde je prazdny nebo kde drzi starou hodnotu.
     * Zaznamy uprav primo v seznamu; volajici je pak ulozi (nebo necha triggeru).
     */
    public static void apply(List<GiftTransaction> records) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Set<Id> darujmeTransactionIds = new Set<Id>();
        Set<Id> commitmentIds = new Set<Id>();
        for (GiftTransaction gt : records) {
            if (gt.npc_bridge__Darujme_Transaction__c != null) {
                darujmeTransactionIds.add(gt.npc_bridge__Darujme_Transaction__c);
            }
            if (gt.GiftCommitmentId != null) {
                commitmentIds.add(gt.GiftCommitmentId);
            }
        }

        Map<Id, String> darujmeMethodByTransaction = new Map<Id, String>();
        if (!darujmeTransactionIds.isEmpty()) {
            for (CRMforNonProfit__Darujme_Transaction__c dt : [
                    SELECT Id, CRMforNonProfit__Pledge__r.CRMforNonProfit__Payment_Method__c
                    FROM CRMforNonProfit__Darujme_Transaction__c
                    WHERE Id IN :darujmeTransactionIds
            ]) {
                darujmeMethodByTransaction.put(dt.Id, dt.CRMforNonProfit__Pledge__r?.CRMforNonProfit__Payment_Method__c);
            }
        }

        Map<Id, GiftCommitment> commitments = new Map<Id, GiftCommitment>();
        if (!commitmentIds.isEmpty()) {
            commitments = new Map<Id, GiftCommitment>([
                    SELECT Id, Payment_Method__c, Comgate_Variable_Symbol__c, Comgate_Initial_Transaction_Id__c,
                            npc_bridge__Darujme_Pledge__c,
                            npc_bridge__Darujme_Pledge__r.CRMforNonProfit__Payment_Method__c
                    FROM GiftCommitment
                    WHERE Id IN :commitmentIds
            ]);
        }

        Map<Id, String> paymentOptions = paymentOptionByGift(records);

        for (GiftTransaction gt : records) {
            GiftCommitment gc = gt.GiftCommitmentId == null ? null : commitments.get(gt.GiftCommitmentId);
            String resolved = resolve(gt, gc, darujmeMethodByTransaction, paymentOptions);
            if (resolved != null && isOverwritable(gt.PaymentMethod)) {
                gt.PaymentMethod = resolved;
            }
        }
    }

    /**
     * Prepisujeme prazdne pole, stare hodnoty a hodnoty, ktere jsme drive dopocitali sami.
     * Cokoli jineho si do pole dal uzivatel rucne a to nechavame byt.
     */
    @TestVisible
    private static Boolean isOverwritable(String current) {
        if (String.isBlank(current) || LEGACY.contains(current)) {
            return true;
        }
        return current.startsWith('Comgate - ') || current.startsWith('Darujme - ');
    }

    private static String resolve(GiftTransaction gt, GiftCommitment gc, Map<Id, String> darujmeMethodByTransaction,
            Map<Id, String> paymentOptions) {
        // 1. bankovni vypis z FIO
        if (gt.npc_bridge__SourceFpackTransaction__c != null) {
            return FIO;
        }

        // 2. Darujme - metoda sedi na Pledge, ke kteremu se dostaneme pres transakci nebo pres zavazek
        if (gt.npc_bridge__Darujme_Transaction__c != null) {
            return darujmeMethod(darujmeMethodByTransaction.get(gt.npc_bridge__Darujme_Transaction__c));
        }
        if (gc != null && gc.npc_bridge__Darujme_Pledge__c != null) {
            return darujmeMethod(gc.npc_bridge__Darujme_Pledge__r?.CRMforNonProfit__Payment_Method__c);
        }
        if (gt.PaymentMethod == 'Darujme') {
            return 'Darujme - Ostatní';
        }

        // 3. Comgate - jen kdyz je zaznam prokazatelne z brany, jinak nechame byt
        if (!isComgate(gt, gc)) {
            return null;
        }
        String raw = gt.Payment_Method__c;
        if (String.isBlank(raw) && gc != null) {
            raw = gc.Payment_Method__c;
        }
        if (String.isBlank(raw)) {
            // webhook jeste nedorazil nebo platba selhala drive, nez brana metodu nahlasila
            String fromOption = optionMethod(paymentOptions.get(gt.Id));
            if (fromOption != null) {
                return fromOption;
            }
        }
        if (String.isBlank(raw)) {
            if (isDerived(gt.PaymentMethod)) {
                // uz je to nas tvar a nemame cim ho zpresnit - jinak bychom ho prelozili na 'Ostatni'
                return gt.PaymentMethod;
            }
            raw = gt.PaymentMethod;
        }
        return comgateMethod(raw);
    }

    /** Volba darce z formulare, kdyz brana metodu nikdy nenahlasila. */
    private static String optionMethod(String paymentOption) {
        if (String.isBlank(paymentOption)) {
            return null;
        }
        switch on paymentOption.toLowerCase() {
            when 'card' {
                return 'Comgate - Karta';
            }
            when 'banktransfer' {
                return 'Comgate - Převod';
            }
            when 'paypal' {
                return 'Comgate - PayPal';
            }
        }
        return null;
    }

    private static Boolean isDerived(String value) {
        return value != null && (value.startsWith('Comgate - ') || value.startsWith('Darujme - '));
    }

    /** Volbu z formulare drzi Payment_Reference__c v JSON payloadu darovaciho formulare. */
    private static Map<Id, String> paymentOptionByGift(List<GiftTransaction> records) {
        Map<Id, String> options = new Map<Id, String>();
        Set<Id> giftIds = new Set<Id>();
        for (GiftTransaction gt : records) {
            if (gt.Id != null && String.isBlank(gt.Payment_Method__c)) {
                giftIds.add(gt.Id);
            }
        }
        if (giftIds.isEmpty()) {
            return options;
        }
        for (Payment_Reference__c pr : [
                SELECT Gift_Transaction__c, JSON_Payment_Wrapper__c
                FROM Payment_Reference__c
                WHERE Gift_Transaction__c IN :giftIds
        ]) {
            String option = readPaymentOption(pr.JSON_Payment_Wrapper__c);
            if (option != null) {
                options.put(pr.Gift_Transaction__c, option);
            }
        }
        return options;
    }

    private static String readPaymentOption(String payload) {
        if (String.isBlank(payload)) {
            return null;
        }
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(payload);
            Object option = parsed.get('paymentOption');
            return option == null ? null : String.valueOf(option);
        } catch (Exception e) {
            return null;
        }
    }

    private static Boolean isComgate(GiftTransaction gt, GiftCommitment gc) {
        if (gt.ProcessorReference == 'Comgate') {
            return true;
        }
        if (gt.Comgate_Transaction_Id__c != null || gt.Comgate_Variable_Symbol__c != null) {
            return true;
        }
        if (String.isNotBlank(gt.Payment_Method__c)) {
            return true;
        }
        if (gc != null && (gc.Comgate_Variable_Symbol__c != null
                || gc.Comgate_Initial_Transaction_Id__c != null
                || String.isNotBlank(gc.Payment_Method__c))) {
            return true;
        }
        return false;
    }

    /************** Migrace historickych dat **************/

    /**
     * Prepocita PaymentMethod na vsech darech, ktere jeste drzi starou hodnotu.
     * Vraci pocet zmenenych zaznamu. Volat z anonymniho Apexu po nasazeni.
     */
    public static Integer migrate() {
        List<GiftTransaction> records = [
                SELECT Id, PaymentMethod, Payment_Method__c, ProcessorReference,
                        Comgate_Transaction_Id__c, Comgate_Variable_Symbol__c,
                        GiftCommitmentId, npc_bridge__Darujme_Transaction__c,
                        npc_bridge__SourceFpackTransaction__c
                FROM GiftTransaction
                LIMIT 10000
        ];
        Map<Id, String> before = new Map<Id, String>();
        for (GiftTransaction gt : records) {
            before.put(gt.Id, gt.PaymentMethod);
        }

        apply(records);

        List<GiftTransaction> changed = new List<GiftTransaction>();
        for (GiftTransaction gt : records) {
            if (gt.PaymentMethod != before.get(gt.Id)) {
                changed.add(gt);
            }
        }
        if (!changed.isEmpty()) {
            update changed;
        }
        return changed.size();
    }

    /**
     * Totez pro splatkove kalendare. Z nich dedi PaymentMethod kazda budouci splatka,
     * kterou zaklada standardni NPC flow, takze ma smysl je srovnat taky.
     *
     * Salesforce ale pole zamyka, jakmile kalendar ma splatky ('You can't edit this field
     * because the schedule has transactions'), takze se casto neprepise nic. Na vysledku
     * to nic nemeni - hodnotu na samotnem daru stejne srovna trigger.
     */
    public static Integer migrateSchedules() {
        List<GiftCommitmentSchedule> schedules = [
                SELECT Id, PaymentMethod, GiftCommitmentId,
                        GiftCommitment.Payment_Method__c,
                        GiftCommitment.npc_bridge__Darujme_Pledge__c,
                        GiftCommitment.npc_bridge__Darujme_Pledge__r.CRMforNonProfit__Payment_Method__c
                FROM GiftCommitmentSchedule
                LIMIT 10000
        ];

        List<GiftCommitmentSchedule> changed = new List<GiftCommitmentSchedule>();
        for (GiftCommitmentSchedule s : schedules) {
            if (s.GiftCommitmentId == null || !isOverwritable(s.PaymentMethod)) {
                continue;
            }
            String resolved = s.GiftCommitment.npc_bridge__Darujme_Pledge__c != null
                    ? darujmeMethod(s.GiftCommitment.npc_bridge__Darujme_Pledge__r?.CRMforNonProfit__Payment_Method__c)
                    : comgateMethod(s.GiftCommitment.Payment_Method__c);
            if (resolved != null && resolved != s.PaymentMethod) {
                s.PaymentMethod = resolved;
                changed.add(s);
            }
        }
        Integer updated = 0;
        for (Database.SaveResult sr : Database.update(changed, false)) {
            if (sr.isSuccess()) {
                updated++;
            }
        }
        return updated;
    }
}
