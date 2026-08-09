// Naplneni praveho sloupce Home stranky (pole Campaign.Donation_Page_Detail__c).
// Spustte v Developer Console > Debug > Open Execute Anonymous Window.
// Pole se nastavuje dynamicky pres put(), protoze Execute Anonymous pri kompilaci
// vynucuje viditelnost poli (FLS) - nove nasazena pole ji jeste nemaji.
// (Doporuceni: pote si v Setup > Object Manager > Campaign > Fields nastavte
// u poli Donation_Page_* viditelnost pro profil System Administrator,
// at je vidite i v UI kampane.)
// Styly (nadpis, kulata fotka, barevne odznaky) dodava DonationPageCss.
// Cisla (17 000 deti, 28 mil. Kc) prosim overte/aktualizujte podle skutecnosti.
SObject c = Schema.getGlobalDescribe().get('Campaign').newSObject();
c.put('Id', '701Te00000gDlc7IAC');
c.put('Donation_Page_Detail__c',
      '<h1>Kroužek pro každé dítě</h1>'
    + '<p><img src="https://czechcouncilofchildrenandyouth.my.site.com/donations/sfsites/c/resource/DonationPageCampaignPhoto" alt="Děti na kroužku"></img></p>'
    + '<p>Každé dítě si zaslouží svůj kroužek — sport, hudbu, tvoření nebo skauting. '
    + 'Pro tisíce rodin v Česku jsou ale volnočasové aktivity finančně nedostupné.</p>'
    + '<p>Váš dar pomůže zaplatit kroužek konkrétnímu dítěti z rodiny v tíživé situaci. '
    + 'Projekt Darujeme kroužky dětem už pomohl více než <b>17&nbsp;000 dětem</b> částkou přes <b>28&nbsp;milionů&nbsp;Kč</b>.</p>'
    + '<p><b>Dobrodružství</b> <b>Kamarádi</b> <b>Dovednosti</b></p>');
update c;
System.debug('Donation_Page_Detail__c nastaveno.');
