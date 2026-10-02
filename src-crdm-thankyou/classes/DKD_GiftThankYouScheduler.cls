/**
 * Dozorci job k dekovnym e-mailum. Flow spousti podekovani hned po zaplaceni, ale bezi
 * v kontextu uzivatele, ktery platbu zapsal (u Comgate webhooku je to guest user site).
 * Tento job bezi jako uzivatel, ktery ho naplanoval (admin), a jednou za ctvrt hodiny
 * dobere jednorazove zaplacene dary, ktere jeste nemaji odeslane podekovani.
 * Dary vznikle pred nasazenim (START) se nechavaji byt, aby se stari darci neobesilali zpetne.
 * Dobira i dary importovane z Darujme - dekuje se za kazdy jednorazovy dar bez rozdilu kanalu.
 * Pravidelne dary sem nepatri: za zavazek se dekuje jen jednou a hlida to DKD_GiftThankYouService,
 * takze dozorci job by k nim nemel co dodat.
 */
public without sharing class DKD_GiftThankYouScheduler implements Schedulable {

    public static final String JOB_NAME = 'DKD podekovani za dar';
    public static final Datetime START = Datetime.newInstanceGmt(2026, 9, 9, 12, 0, 0);
    public static final Integer BATCH_LIMIT = 200;

    public void execute(SchedulableContext context) {
        enqueuePending();
    }

    public static Integer enqueuePending() {
        // Bez overene organizacni adresy by kazdy beh jen plnil Error Log - radeji pockat, dary zustavaji To Be Sent
        if (!DKD_GiftThankYouService.isFromAddressReady()) {
            System.debug(LoggingLevel.WARN, 'DKD podekovani: organizacni adresa ' + DKD_GiftThankYouService.FROM_ADDRESS + ' neni pripravena, cekam.');
            return 0;
        }
        // Jen darci, kam lze poslat - stejna pole jako DKD_GiftThankYouService. Dar na zaloznim uctu
        // Default (platba z vypisu od nezname osoby) by se jinak zkousel kazdych 15 minut a kazdy pokus
        // zapsal chybu. Stav zustava To Be Sent: jakmile dar dostane darce s e-mailem, job ho sam dobere.
        List<GiftTransaction> pending = [
            SELECT Id FROM GiftTransaction
            WHERE Status = 'Paid'
            AND GiftCommitmentId = null
            AND AcknowledgementStatus = 'To Be Sent'
            AND CreatedDate >= :START
            AND (Donor.PersonEmail != null OR Donor.npc_bridge__PrimaryContact__r.Email != null)
            LIMIT :BATCH_LIMIT
        ];
        if (!pending.isEmpty()) {
            System.enqueueJob(new DKD_GiftThankYouQueueable(new List<Id>(new Map<Id, GiftTransaction>(pending).keySet())));
        }
        return pending.size();
    }

    // Naplanuje ctyri behy za hodinu; existujici stejnojmenne joby nejdriv zrusi
    public static void scheduleEveryQuarterHour() {
        for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE :(JOB_NAME + '%')]) {
            System.abortJob(ct.Id);
        }
        for (Integer minute : new List<Integer>{ 0, 15, 30, 45 }) {
            System.schedule(JOB_NAME + ' :' + (minute < 10 ? '0' : '') + minute, '0 ' + minute + ' * * * ?', new DKD_GiftThankYouScheduler());
        }
    }
}