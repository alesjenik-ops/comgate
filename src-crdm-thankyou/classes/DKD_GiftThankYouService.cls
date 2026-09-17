/**
 * Dekovny e-mail darci po zaplaceni daru - jednorazoveho i pravidelneho.
 *
 * Volano z record-triggered flow Gift_Transaction_Thank_You_Email pres invocable metodu.
 * Flow bezi v kontextu uzivatele, ktery platbu zapsal - u Comgate webhooku je to guest user
 * site, ktery nema prava na pole, VF stranku ani odeslani e-mailu. Invocable metoda proto jen
 * publikuje platform event DKD_Thank_You_Requested__e; jeho trigger bezi podle
 * PlatformEventSubscriberConfig jako spravce a teprve ten zaradi praci do Queueable
 * (DKD_GiftThankYouQueueable), protoze generovani PDF je callout a nesmi probehnout
 * v trigger kontextu ani po DML. E-mail tak odchazi behem nekolika sekund po platbe.
 *
 * Jednorazovy dar (GiftCommitmentId je prazdne):
 *  1. PDF potvrzeni z npc_bridge__PDF_Template__c pres VF stranku balicku GiftConfirmationPDF
 *  2. e-mail ze sablony DKD_Thank_You_One_Time, merge pole {!GiftTransaction.X} se plni primo z transakce
 *  3. odeslani z organizacni adresy, ulozeni jako EmailMessage pod kontakt darce (saveAsActivity)
 *  4. PDF se ulozi jako soubor k transakci
 *  5. AcknowledgementStatus a TaxReceiptStatus = Sent, AcknowledgementDate = dnes
 *
 * Pravidelny dar (GiftCommitmentId je vyplnene):
 *  - dekuje se jen za PRVNI zaplacenou platbu zavazku, dalsi splatky se tise preskoci
 *  - e-mail ze sablony DKD_Thank_You_Recurring, BEZ PDF prilohy
 *  - nastavuje se jen AcknowledgementStatus a AcknowledgementDate, TaxReceiptStatus zustava
 *
 * Drive posilal pravidelne podekovani primo flow akci emailSimple z organizacni adresy. To
 * z guest kontextu neprojde ("Org-Wide Email provided is not valid") a protoze akce bezela
 * v transakci webhooku, shodila cely zapis platby. Proto obe vetve chodi touhle cestou.
 *
 * Chyby se zapisuji do CRMforNonProfit__Error_Log__c a transakce zustava To Be Sent.
 */
public without sharing class DKD_GiftThankYouService {

    public static final String EMAIL_TEMPLATE_DEV_NAME = 'DKD_Thank_You_One_Time';
    public static final String EMAIL_TEMPLATE_RECURRING_DEV_NAME = 'DKD_Thank_You_Recurring';
    public static final String PDF_TEMPLATE_NAME = 'Potvrzeni o daru DKD';
    public static final String FROM_ADDRESS = 'darci@darujemekrouzky.cz';
    public static final String PDF_PAGE_PATH = '/apex/npc_bridge__GiftConfirmationPDF';
    public static final String STATUS_SENT = 'Sent';
    public static final String STATUS_TO_BE_SENT = 'To Be Sent';
    // Callout limit je 100 na transakci, kazde PDF je jeden callout
    public static final Integer CHUNK_SIZE = 40;

    @TestVisible private static String emailTemplateDevName = EMAIL_TEMPLATE_DEV_NAME;
    @TestVisible private static String recurringTemplateDevName = EMAIL_TEMPLATE_RECURRING_DEV_NAME;
    @TestVisible private static String pdfTemplateName = PDF_TEMPLATE_NAME;
    @TestVisible private static Blob pdfOverride;

    private static final Pattern TOKEN = Pattern.compile('\\{!GiftTransaction\\.([A-Za-z0-9_]+)\\}');

    public class Request {
        @InvocableVariable(label='Gift Transaction Id' required=true)
        public Id giftTransactionId;
    }

    public class Outcome {
        public Id transactionId;
        public Boolean success = false;
        public String message;
        public String recipientEmail;
    }

    @InvocableMethod(label='DKD: Poslat podekovani s potvrzenim o daru'
        description='Publikuje platform event DKD_Thank_You_Requested__e. Jeho trigger bezi jako spravce, vygeneruje PDF potvrzeni, posle dekovny e-mail a ulozi ho jako EmailMessage. Bezi asynchronne, behem nekolika sekund.'
        category='Gift Transaction')
    public static void enqueue(List<Request> requests) {
        Set<Id> seen = new Set<Id>();
        List<DKD_Thank_You_Requested__e> events = new List<DKD_Thank_You_Requested__e>();
        for (Request r : requests) {
            if (r == null || r.giftTransactionId == null || !seen.add(r.giftTransactionId)) continue;
            events.add(new DKD_Thank_You_Requested__e(Gift_Transaction_Id__c = String.valueOf(r.giftTransactionId)));
        }
        if (events.isEmpty()) return;
        // Kdyz publikace selze, dar zustava To Be Sent a do 15 minut ho dobere dozorci job
        for (Database.SaveResult sr : EventBus.publish(events)) {
            if (!sr.isSuccess()) System.debug(LoggingLevel.ERROR, 'DKD podekovani: event se nepodarilo publikovat: ' + sr.getErrors());
        }
    }

    // Vola trigger DKD_ThankYouRequestedTrigger. Bezi pod uzivatelem z PlatformEventSubscriberConfig
    // (spravce), takze Queueable, ktery odsud vznikne, ma prava na pole, VF stranku i odeslani e-mailu.
    public static void handleRequestedEvents(List<DKD_Thank_You_Requested__e> events) {
        Set<Id> ids = new Set<Id>();
        for (DKD_Thank_You_Requested__e e : events) {
            if (e == null || String.isBlank(e.Gift_Transaction_Id__c)) continue;
            try {
                Id tid = Id.valueOf(e.Gift_Transaction_Id__c);
                if (tid.getSobjectType() == GiftTransaction.SObjectType) ids.add(tid);
            } catch (Exception ex) {
                System.debug(LoggingLevel.WARN, 'DKD podekovani: neplatne Id v eventu: ' + e.Gift_Transaction_Id__c);
            }
        }
        if (!ids.isEmpty()) System.enqueueJob(new DKD_GiftThankYouQueueable(new List<Id>(ids)));
    }

    public static List<Outcome> process(List<Id> transactionIds) {
        List<Outcome> outcomes = new List<Outcome>();
        if (transactionIds == null || transactionIds.isEmpty()) return outcomes;

        Map<String, EmailTemplate> templates = loadEmailTemplates();
        npc_bridge__PDF_Template__c pdfTemplate = loadPdfTemplate();
        // Kdyz neni ani jedna sablona, nema smysl pokracovat. Chybejici PDF sablona se resi az
        // u konkretni transakce - pravidelny dar ji nepotrebuje.
        if (templates.isEmpty()) {
            String problem = 'Chybi aktivni e-mailova sablona ' + emailTemplateDevName
                + ' i ' + recurringTemplateDevName;
            for (Id tid : transactionIds) outcomes.add(fail(tid, problem));
            logErrors(outcomes);
            return outcomes;
        }
        String accessProblem = missingFieldAccess();
        if (accessProblem != null) {
            for (Id tid : transactionIds) outcomes.add(fail(tid, accessProblem));
            logErrors(outcomes);
            return outcomes;
        }
        Id fromAddressId;
        try {
            fromAddressId = loadFromAddressId();
        } catch (FromAddressException e) {
            for (Id tid : transactionIds) outcomes.add(fail(tid, e.getMessage()));
            logErrors(outcomes);
            return outcomes;
        }

        // Merge pole se ctou dynamicky z obou sablon najednou, aby sly upravovat bez zasahu do kodu -
        // davka muze obsahovat jednorazove i pravidelne dary a dopredu nevime, ktere sablony budou potreba
        Set<String> fields = new Set<String>{
            'Id', 'Name', 'DonorId', 'Donor.Name', 'Donor.PersonContactId', 'Donor.PersonEmail',
            'Donor.npc_bridge__PrimaryContact__c', 'Donor.npc_bridge__PrimaryContact__r.Email',
            'AcknowledgementStatus', 'Transaction_Year__c', 'GiftCommitmentId'
        };
        for (EmailTemplate t : templates.values()) {
            fields.addAll(extractTokenFields(t.Subject + ' ' + t.HtmlValue + ' ' + t.Body));
        }
        List<GiftTransaction> transactions = Database.query(
            'SELECT ' + String.join(new List<String>(fields), ', ')
            + ' FROM GiftTransaction WHERE Id IN :transactionIds'
        );

        Set<Id> thankedCommitments = loadThankedCommitments(transactions);

        // 1. faze: callouty (PDF) a priprava mailu - zadne DML
        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        List<GiftTransaction> mailTransactions = new List<GiftTransaction>();
        List<Blob> pdfs = new List<Blob>();
        List<String> fileNames = new List<String>();
        List<Outcome> mailOutcomes = new List<Outcome>();

        for (GiftTransaction gt : transactions) {
            if (gt.AcknowledgementStatus == STATUS_SENT) {
                Outcome skipped = fail(gt.Id, 'Podekovani uz bylo odeslano, preskoceno.');
                skipped.success = true;
                outcomes.add(skipped);
                continue;
            }
            // Za pravidelny dar se dekuje jednou za zavazek. add() vrati false, kdyz uz zavazek
            // podekovani dostal - drive, nebo jinou splatkou ze stejne davky.
            Boolean isRecurring = gt.GiftCommitmentId != null;
            if (isRecurring && !thankedCommitments.add(gt.GiftCommitmentId)) {
                Outcome skipped = fail(gt.Id, 'Za tento zavazek uz podekovani odeslo, preskoceno.');
                skipped.success = true;
                outcomes.add(skipped);
                continue;
            }
            String templateName = isRecurring ? recurringTemplateDevName : emailTemplateDevName;
            EmailTemplate template = templates.get(templateName);
            if (template == null) {
                outcomes.add(fail(gt.Id, 'Chybi aktivni e-mailova sablona ' + templateName));
                continue;
            }
            // PDF potvrzeni se priklada jen k jednorazovemu daru, pravidelny ho nepotrebuje
            if (!isRecurring && pdfTemplate == null) {
                outcomes.add(fail(gt.Id, 'Chybi aktivni PDF sablona ' + pdfTemplateName));
                continue;
            }
            Id contactId = gt.Donor.PersonContactId != null ? gt.Donor.PersonContactId : gt.Donor.npc_bridge__PrimaryContact__c;
            String email = String.isNotBlank(gt.Donor.PersonEmail) ? gt.Donor.PersonEmail : gt.Donor.npc_bridge__PrimaryContact__r?.Email;
            if (contactId == null || String.isBlank(email)) {
                outcomes.add(fail(gt.Id, 'Darce nema kontakt s vyplnenym e-mailem, podekovani nelze odeslat.'));
                continue;
            }
            try {
                Blob pdf = isRecurring ? null : generatePdf(gt.Id, pdfTemplate.Id);
                String fileName = isRecurring ? null
                    : 'potvrzeni-o-daru-' + (String.isBlank(gt.Transaction_Year__c) ? 'dkd' : gt.Transaction_Year__c) + '.pdf';

                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTargetObjectId(contactId);
                mail.setSubject(mergeTokens(template.Subject, gt));
                mail.setHtmlBody(mergeTokens(template.HtmlValue, gt));
                mail.setPlainTextBody(mergeTokens(template.Body, gt));
                mail.setSaveAsActivity(true);
                mail.setUseSignature(false);
                if (fromAddressId != null) mail.setOrgWideEmailAddressId(fromAddressId);  // v produkci vzdy vyplnene
                if (pdf != null) {
                    Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                    attachment.setFileName(fileName);
                    attachment.setBody(pdf);
                    attachment.setContentType('application/pdf');
                    mail.setFileAttachments(new List<Messaging.EmailFileAttachment>{ attachment });
                }

                mails.add(mail);
                mailTransactions.add(gt);
                pdfs.add(pdf);
                fileNames.add(fileName);
                Outcome o = new Outcome();
                o.transactionId = gt.Id;
                o.recipientEmail = email;
                mailOutcomes.add(o);
            } catch (Exception e) {
                outcomes.add(fail(gt.Id, 'Generovani potvrzeni selhalo: ' + e.getMessage()));
            }
        }

        // 2. faze: DML a odeslani. Stav Sent se zapisuje PRED odeslanim - kdyby update selhal,
        // nic neodejde a nehrozi, ze by dozorci job poslal podekovani podruhe.
        if (!mails.isEmpty()) {
            List<GiftTransaction> marks = new List<GiftTransaction>();
            for (GiftTransaction gt : mailTransactions) {
                // TaxReceiptStatus se hybe jen u jednorazoveho daru - jen k nemu jde potvrzeni o daru
                GiftTransaction mark = new GiftTransaction(Id = gt.Id, AcknowledgementStatus = STATUS_SENT,
                    AcknowledgementDate = Date.today());
                if (gt.GiftCommitmentId == null) mark.TaxReceiptStatus = STATUS_SENT;
                marks.add(mark);
            }
            update marks;

            List<Messaging.SendEmailResult> results = Messaging.sendEmail(mails, false);
            List<GiftTransaction> reverts = new List<GiftTransaction>();
            List<ContentVersion> files = new List<ContentVersion>();
            for (Integer i = 0; i < results.size(); i++) {
                Outcome o = mailOutcomes[i];
                if (results[i].isSuccess()) {
                    o.success = true;
                    o.message = 'Odeslano na ' + o.recipientEmail;
                    if (pdfs[i] != null) {
                        files.add(new ContentVersion(
                            Title = fileNames[i].removeEnd('.pdf'),
                            PathOnClient = fileNames[i],
                            VersionData = pdfs[i],
                            FirstPublishLocationId = mailTransactions[i].Id
                        ));
                    }
                } else {
                    o.message = 'Odeslani e-mailu selhalo: ' + results[i].getErrors()[0].getMessage();
                    GiftTransaction revert = new GiftTransaction(Id = mailTransactions[i].Id,
                        AcknowledgementStatus = STATUS_TO_BE_SENT, AcknowledgementDate = null);
                    if (mailTransactions[i].GiftCommitmentId == null) revert.TaxReceiptStatus = STATUS_TO_BE_SENT;
                    reverts.add(revert);
                }
                outcomes.add(o);
            }
            if (!reverts.isEmpty()) update reverts;
            // Soubor je bonus - kdyz se neulozi (napr. prava guest usera), e-mail uz odesel a stav je Sent
            if (!files.isEmpty()) {
                try { insert files; } catch (Exception e) { System.debug(LoggingLevel.WARN, 'PDF se nepodarilo ulozit k transakci: ' + e.getMessage()); }
            }
        }

        logErrors(outcomes);
        return outcomes;
    }

    // Zavazky, za ktere uz podekovani odeslo. Rozhoduje stav zavazku, NE poradi splatnosti:
    // splatky se plati i mimo poradi - neuspesna splatka pravidelneho daru zustava Unpaid
    // (webhook ji Failed nenastavi) a ComgateChargePaymentsBatch ji nabiji znovu. Kdyby se
    // vybiralo podle TransactionDueDate, zaplacenim starsi splatky by se "prvni platbou" stala
    // jina transakce a darci by odeslo druhe podekovani za tyz zavazek.
    @TestVisible
    private static Set<Id> loadThankedCommitments(List<GiftTransaction> transactions) {
        Set<Id> commitmentIds = new Set<Id>();
        for (GiftTransaction gt : transactions) {
            if (gt.GiftCommitmentId != null) commitmentIds.add(gt.GiftCommitmentId);
        }
        Set<Id> thanked = new Set<Id>();
        if (commitmentIds.isEmpty()) return thanked;
        for (GiftTransaction gt : [SELECT GiftCommitmentId FROM GiftTransaction
                WHERE GiftCommitmentId IN :commitmentIds AND AcknowledgementStatus = :STATUS_SENT]) {
            thanked.add(gt.GiftCommitmentId);
        }
        return thanked;
    }

    /* ================= pomocne ================= */

    // VF stranka balicku cte transakci v USER_MODE - bez FLS na nova pole by vratila PDF s chybovou hlaskou misto vyjimky
    public static final List<String> RECEIPT_FIELDS = new List<String>{
        'Transaction_Year__c', 'Receipt_Donor_Name__c', 'Receipt_Donor_Email__c', 'Receipt_Donor_Address__c', 'Thank_You_Amount__c', 'Thank_You_Donor_Name__c'
    };
    @TestVisible
    private static String missingFieldAccess() {
        if (Test.isRunningTest()) return null;
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.GiftTransaction.fields.getMap();
        List<String> missing = new List<String>();
        for (String f : RECEIPT_FIELDS) {
            Schema.SObjectField sf = fieldMap.get(f);
            if (sf == null || !sf.getDescribe().isAccessible()) missing.add(f);
        }
        return missing.isEmpty() ? null : 'Uzivatel ' + UserInfo.getUserName() + ' nema pristup k polim ' + String.join(missing, ', ')
            + ' - priradte mu permission set DKD_Thank_You_Automation.';
    }

    // Obe sablony najednou: DKD_Thank_You_One_Time pro jednorazovy dar, DKD_Thank_You_Recurring
    // pro prvni zaplacenou platbu zavazku. Klicem je DeveloperName.
    private static Map<String, EmailTemplate> loadEmailTemplates() {
        Set<String> names = new Set<String>{ emailTemplateDevName, recurringTemplateDevName };
        Map<String, EmailTemplate> byName = new Map<String, EmailTemplate>();
        for (EmailTemplate t : [
            SELECT Id, DeveloperName, Subject, HtmlValue, Body FROM EmailTemplate
            WHERE DeveloperName IN :names AND IsActive = true
        ]) {
            byName.put(t.DeveloperName, t);
        }
        return byName;
    }

    private static npc_bridge__PDF_Template__c loadPdfTemplate() {
        List<npc_bridge__PDF_Template__c> templates = [
            SELECT Id, npc_bridge__Filename__c FROM npc_bridge__PDF_Template__c
            WHERE Name = :pdfTemplateName AND npc_bridge__Active__c = true LIMIT 1
        ];
        return templates.isEmpty() ? null : templates[0];
    }

    // Odesila se VYHRADNE z organizacni adresy darci@darujemekrouzky.cz. Zadny fallback na adresu
    // uzivatele - kdyz adresa chybi nebo neni overena, nic neodejde a transakce zustane To Be Sent.
    @TestVisible private static Boolean requireOrgWideAddress = true;
    // Testy si sem daji neexistujici adresu, aby nezavisely na tom, jestli je darci@ v orgu overena
    @TestVisible private static String fromAddress = FROM_ADDRESS;

    public class FromAddressException extends Exception {}

    @TestVisible
    private static Id loadFromAddressId() {
        List<OrgWideEmailAddress> addresses = [SELECT Id, IsVerified FROM OrgWideEmailAddress WHERE Address = :fromAddress LIMIT 1];
        if (!addresses.isEmpty() && addresses[0].IsVerified) return addresses[0].Id;
        if (!requireOrgWideAddress) return null;
        throw new FromAddressException(addresses.isEmpty()
            ? 'Organizacni adresa ' + fromAddress + ' v orgu neexistuje. Zalozte ji v Setup > Organization-Wide Addresses.'
            : 'Organizacni adresa ' + fromAddress + ' neni overena. Potvrdte overovaci e-mail (Setup > Organization-Wide Addresses > Resend verification).');
    }

    // Pro dozorci job: kdyz adresa neni pripravena, nema smysl nic radit do fronty
    public static Boolean isFromAddressReady() {
        try { loadFromAddressId(); return true; } catch (FromAddressException e) { return false; }
    }

    @TestVisible
    private static Set<String> extractTokenFields(String text) {
        Set<String> fields = new Set<String>();
        if (String.isBlank(text)) return fields;
        Matcher m = TOKEN.matcher(text);
        while (m.find()) fields.add(m.group(1));
        return fields;
    }

    @TestVisible
    private static String mergeTokens(String text, GiftTransaction gt) {
        if (String.isBlank(text)) return text;
        Matcher m = TOKEN.matcher(text);
        String result = text;
        Set<String> done = new Set<String>();
        while (m.find()) {
            String token = m.group(0);
            if (done.contains(token)) continue;
            done.add(token);
            Object value;
            try { value = gt.get(m.group(1)); } catch (Exception e) { value = null; }
            result = result.replace(token, value == null ? '' : String.valueOf(value));
        }
        return result;
    }

    private static Blob generatePdf(Id transactionId, Id pdfTemplateId) {
        if (Test.isRunningTest()) {
            return pdfOverride != null ? pdfOverride : Blob.valueOf('PDF-TEST');
        }
        PageReference page = new PageReference(PDF_PAGE_PATH);
        page.getParameters().put('id', transactionId);
        page.getParameters().put('templateId', pdfTemplateId);
        return page.getContentAsPDF();
    }

    private static Outcome fail(Id transactionId, String message) {
        Outcome o = new Outcome();
        o.transactionId = transactionId;
        o.message = message;
        return o;
    }

    private static void logErrors(List<Outcome> outcomes) {
        List<CRMforNonProfit__Error_Log__c> logs = new List<CRMforNonProfit__Error_Log__c>();
        for (Outcome o : outcomes) {
            if (o.success) continue;
            logs.add(new CRMforNonProfit__Error_Log__c(
                CRMforNonProfit__Class_Name__c = 'DKD_GiftThankYouService',
                CRMforNonProfit__Error_Message__c = o.message,
                CRMforNonProfit__Record_Id__c = String.valueOf(o.transactionId),
                CRMforNonProfit__Keyword__c = 'DKD podekovani'
            ));
        }
        if (logs.isEmpty()) return;
        try { insert logs; } catch (Exception e) { System.debug(LoggingLevel.ERROR, 'Error log se nepodarilo zapsat: ' + e.getMessage()); }
    }
}
