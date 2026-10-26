// Odhlaseni z e-mailu: https://darci.darujemekrouzky.cz/services/apexrest/odhlaseni?t=<token>
// GET jen ukaze stranku s tlacitkem - odkazy v e-mailech otevira i antispam (Outlook Safe Links,
// Gmail), takze samotne otevreni odkazu nesmi nikoho odhlasit. Odhlasi az POST z tlacitka.
// Bezi jako guest user site, proto without sharing.
@RestResource(urlMapping='/odhlaseni')
global without sharing class DKD_UnsubscribeResource {

    @TestVisible static final String SUBJECT = 'Odhlášení z newsletteru';
    static final Pattern TOKEN_FORMAT = Pattern.compile('^[0-9a-f]{32}$');

    @HttpGet
    global static void showPage() {
        Contact c = findContact();
        if (c == null) { respond(400, page('Odkaz není platný', '<p>Tento odkaz pro odhlášení neznáme. Zkontrolujte prosím, že jste ho zkopírovali celý, nebo nám napište na <a href="mailto:darci@darujemekrouzky.cz">darci@darujemekrouzky.cz</a>.</p>')); return; }
        if (!isSubscribed(c)) { respond(200, page('Už jste odhlášeni', '<p>Newslettery Darujeme kroužky dětem vám už neposíláme.</p>')); return; }
        String token = token();
        respond(200, page('Odhlášení z newsletteru',
            '<p>Opravdu už nechcete dostávat newslettery Darujeme kroužky dětem?</p>'
            + '<form method="post" action="?t=' + token + '"><button type="submit">Odhlásit se</button></form>'
            + '<p class="small">Potvrzení o daru a důležité informace k vašim darům vám budeme posílat dál.</p>'));
    }

    @HttpPost
    global static void unsubscribe() {
        Contact c = findContact();
        if (c == null) { respond(400, page('Odkaz není platný', '<p>Tento odkaz pro odhlášení neznáme. Napište nám prosím na <a href="mailto:darci@darujemekrouzky.cz">darci@darujemekrouzky.cz</a>.</p>')); return; }
        if (isSubscribed(c)) {
            Database.DMLOptions dml = new Database.DMLOptions();
            dml.duplicateRuleHeader.allowSave = true;
            dml.OptAllOrNone = true;
            // osobni kontakt nejde upravit primo, jen pres jeho ucet
            if (c.IsPersonAccount) {
                Database.update(new Account(Id = c.AccountId, CRMforNonProfit__Newsletter__pc = false), dml);
            } else {
                Database.update(new Contact(Id = c.Id, CRMforNonProfit__Newsletter__c = false), dml);
            }
            insert new Task(
                Subject = SUBJECT,
                WhoId = c.Id,
                OwnerId = c.Owner.IsActive ? c.OwnerId : UserInfo.getUserId(),
                Status = 'Completed',
                Priority = 'Normal',
                ActivityDate = Date.today(),
                Description = 'Dárce se odhlásil z newsletteru odkazem v e-mailu. Pole Newsletter bylo nastaveno na false.'
            );
        }
        respond(200, page('Odhlášení proběhlo', '<p>Newslettery Darujeme kroužky dětem vám už nebudeme posílat. Děkujeme, že jste s námi byli.</p>'));
    }

    private static String token() {
        String t = RestContext.request.params.get('t');
        return t == null ? null : t.trim().toLowerCase();
    }

    private static Contact findContact() {
        String t = token();
        if (t == null || !TOKEN_FORMAT.matcher(t).matches()) return null;
        List<Contact> found = [
            SELECT Id, IsPersonAccount, AccountId, OwnerId, Owner.IsActive, CRMforNonProfit__Newsletter__c
            FROM Contact WHERE DKD_Unsubscribe_Token__c = :t LIMIT 1
        ];
        return found.isEmpty() ? null : found[0];
    }

    private static Boolean isSubscribed(Contact c) {
        return c.CRMforNonProfit__Newsletter__c == true;
    }

    private static void respond(Integer status, String html) {
        RestResponse res = RestContext.response;
        res.statusCode = status;
        res.addHeader('Content-Type', 'text/html; charset=utf-8');
        res.addHeader('Cache-Control', 'no-store');
        res.addHeader('X-Robots-Tag', 'noindex');
        res.responseBody = Blob.valueOf(html);
    }

    @TestVisible
    private static String page(String title, String body) {
        return '<!DOCTYPE html><html lang="cs"><head><meta charset="utf-8">'
            + '<meta name="viewport" content="width=device-width, initial-scale=1"><meta name="robots" content="noindex">'
            + '<title>' + title + ' – Darujeme kroužky dětem</title><style>'
            + 'body{margin:0;background:#f3f0eb;font-family:"Segoe UI",Arial,Helvetica,sans-serif;color:#3d2b38}'
            + 'header{background:#312030;color:#fff;padding:28px 24px}header p{margin:0;font-size:15px;color:#f0e6ee}'
            + 'main{max-width:560px;margin:0 auto;padding:32px 24px}h1{color:#382133;font-size:26px;margin:0 0 16px}'
            + 'p{font-size:16px;line-height:26px}a{color:#382133}.small{font-size:14px;color:#6b5a66}'
            + 'button{background:#fa95c1;color:#382133;border:0;padding:14px 22px;font-size:16px;font-weight:700;cursor:pointer}'
            + '</style></head><body><header><p>Darujeme kroužky dětem</p></header><main><h1>' + title + '</h1>'
            + body + '</main></body></html>';
    }
}