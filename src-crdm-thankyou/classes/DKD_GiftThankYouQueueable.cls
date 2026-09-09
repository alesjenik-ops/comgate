/**
 * Asynchronni obalka nad DKD_GiftThankYouService.process. Zpracuje davku transakci
 * a zbytek posle dal v novem jobu, aby se nepretekl limit calloutu.
 */
public without sharing class DKD_GiftThankYouQueueable implements Queueable, Database.AllowsCallouts {

    private final List<Id> transactionIds;

    public DKD_GiftThankYouQueueable(List<Id> transactionIds) {
        this.transactionIds = transactionIds == null ? new List<Id>() : transactionIds;
    }

    public void execute(QueueableContext context) {
        List<Id> batch = new List<Id>();
        List<Id> rest = new List<Id>();
        for (Id tid : transactionIds) {
            if (batch.size() < DKD_GiftThankYouService.CHUNK_SIZE) batch.add(tid); else rest.add(tid);
        }
        DKD_GiftThankYouService.process(batch);
        if (!rest.isEmpty() && !Test.isRunningTest()) {
            System.enqueueJob(new DKD_GiftThankYouQueueable(rest));
        }
    }
}
