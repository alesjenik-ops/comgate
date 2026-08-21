// Prirazeni permission setu Comgate_Integration guest userovi site a aktualnimu adminovi.
// Spustte v Developer Console > Debug > Open Execute Anonymous Window (nebo Workbench > Apex Execute).
// Guest useri jsou v Setup > Users skryti, proto prirazeni pres Apex.
// Pokud dotaz na guest usera nic nenajde, spuste nejdriv jen SELECT nize a upravte LIKE filtr:
//   SELECT Id, Name, Username FROM User WHERE UserType = 'Guest' AND IsActive = true
PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Comgate_Integration' LIMIT 1];
List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

for (User g : [SELECT Id, Name FROM User WHERE UserType = 'Guest' AND IsActive = true AND Name LIKE '%Donation%']) {
    assignments.add(new PermissionSetAssignment(AssigneeId = g.Id, PermissionSetId = ps.Id));
    System.debug('Guest user: ' + g.Name);
}
assignments.add(new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = ps.Id));

// allOrNone=false: uz existujici prirazeni (DUPLICATE_VALUE) skript neshodi
List<Database.SaveResult> results = Database.insert(assignments, false);
for (Database.SaveResult r : results) {
    System.debug(r.isSuccess() ? 'OK ' + r.getId() : 'CHYBA: ' + r.getErrors()[0].getMessage());
}
