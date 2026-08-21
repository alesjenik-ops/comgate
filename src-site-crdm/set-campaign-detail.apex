// Naplneni praveho sloupce Home stranky (pole Campaign.Donation_Page_Detail__c).
// Spustte v Developer Console > Debug > Open Execute Anonymous Window.
// Pole se nastavuje dynamicky pres put(), protoze Execute Anonymous pri kompilaci
// vynucuje viditelnost poli (FLS) - nove nasazena pole ji jeste nemaji.
// (Doporuceni: pote si v Setup > Object Manager > Campaign > Fields nastavte
// u poli Donation_Page_* viditelnost pro profil System Administrator,
// at je vidite i v UI kampane.)
// Styly (nadpis, kulata fotka) dodava DonationPageCss.
// Cisla (20 000 deti, 33 mil. Kc) prosim overte/aktualizujte podle skutecnosti.
SObject c = Schema.getGlobalDescribe().get('Campaign').newSObject();
c.put('Id', '701Te00000gDlc7IAC');
c.put('Donation_Page_Detail__c',
      '<h1>Kroužek pro každé dítě</h1>'
    + '<p>Každé dítě si zaslouží místo, kde může dělat to, co ho baví. Kroužky dětem přinášejí '
    + 'mnohem víc než smysluplně strávený volný čas – nacházejí v nich kamarády a bezpečné prostředí, '
    + 'objevují své silné stránky, učí se nové věci a získávají zdravé sebevědomí. Pro řadu rodin '
    + 'v Česku jsou ale náklady na sport, hudbu, tvoření, skauting a další aktivity příliš vysoké.</p>'
    + '<p>Váš dar může dítěti otevřít dveře do světa, do kterého by se jinak nedostalo. '
    + 'Projekt Darujeme kroužky dětem už podpořil více než <b>20&nbsp;000 dětí</b> částkou bezmála '
    + '<b>33&nbsp;milionů&nbsp;Kč</b>. Pomozte nám, aby další děti nemusely stát stranou jen kvůli '
    + 'finanční situaci své rodiny. Darujte dětem příležitost dělat to, co je baví, rozvíjí '
    + 'a dává jim pocit, že někam patří. Děkujeme.</p>'
    // relativni URL - absolutni na ...my.site.com blokuje CSP na domene darci.darujemekrouzky.cz
    + '<p><img src="/sfsites/c/resource/DonationPageCampaignPhoto" alt="Děti na kroužku"></img></p>'
    + '<p><a href="https://www.darujemekrouzky.cz/" target="_blank"><b>Více o projektu</b></a></p>');
update c;
System.debug('Donation_Page_Detail__c nastaveno.');
