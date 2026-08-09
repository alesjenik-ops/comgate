// Naplneni praveho sloupce Home stranky (pole Campaign.Donation_Page_Detail__c).
// Spustte v Developer Console > Debug > Open Execute Anonymous Window.
// Styly (velikost nadpisu, kulata fotka, barevne odznaky) dodava DonationPageCss,
// takze HTML je zamerne jednoduche - rich text editor ho nerozbije.
// Cisla (17 000 deti, 28 mil. Kc) prosim overte/aktualizujte podle skutecnosti.
Campaign c = new Campaign(Id = '701Te00000gDlc7IAC');
c.Donation_Page_Detail__c =
      '<h1>Kroužek pro každé dítě</h1>'
    + '<p><img src="https://czechcouncilofchildrenandyouth.my.site.com/donations/sfsites/c/resource/DonationPageCampaignPhoto" alt="Děti na kroužku"></img></p>'
    + '<p>Každé dítě si zaslouží svůj kroužek — sport, hudbu, tvoření nebo skauting. '
    + 'Pro tisíce rodin v Česku jsou ale volnočasové aktivity finančně nedostupné.</p>'
    + '<p>Váš dar pomůže zaplatit kroužek konkrétnímu dítěti z rodiny v tíživé situaci. '
    + 'Projekt Darujeme kroužky dětem už pomohl více než <b>17&nbsp;000 dětem</b> částkou přes <b>28&nbsp;milionů&nbsp;Kč</b>.</p>'
    + '<p><b>Dobrodružství</b> <b>Kamarádi</b> <b>Dovednosti</b></p>';
update c;
System.debug('Donation_Page_Detail__c nastaveno.');
