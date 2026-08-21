// Prirazeni permission setu guest userovi site (Comgate_Integration_Guest - licence
// guest usera nepovoluje objektove Edit/Delete) a aktualnimu adminovi (Comgate_Integration).
// Spustte v Developer Console > Debug > Open Execute Anonymous Window (nebo Workbench > Apex Execute).
// Guest useri jsou v Setup > Users skryti, proto prirazeni pres Apex.
// Pokud dotaz na guest usera nic nenajde, spuste nejdriv jen SELECT nize a upravte LIKE filtr:
//   SELECT Id, Name, Username FROM User WHERE UserType = 'Guest' AND IsActive = true
PermissionSet psGuest = [SELECT Id FROM PermissionSet WHERE Name = 'Comgate_Integration_Guest' LIMIT 1];
PermissionSet psAdmin = [SELECT Id FROM PermissionSet WHERE Name = 'Comgate_Integration' LIMIT 1];
List<PermissionSetAssignment> assignments = new List<PermissionSetAssignment>();

for (User g : [SELECT Id, Name FROM User WHERE UserType = 'Guest' AND IsActive = true AND Name LIKE '%Donation%']) {
    assignments.add(new PermissionSetAssignment(AssigneeId = g.Id, PermissionSetId = psGuest.Id));
    System.debug('Guest user: ' + g.Name);
}
assignments.add(new PermissionSetAssignment(AssigneeId = UserInfo.getUserId(), PermissionSetId = psAdmin.Id));

// allOrNone=false: uz existujici prirazeni (DUPLICATE_VALUE) skript neshodi
List<Database.SaveResult> results = Database.insert(assignments, false);
for (Database.SaveResult r : results) {
    System.debug(r.isSuccess() ? 'OK ' + r.getId() : 'CHYBA: ' + r.getErrors()[0].getMessage());
}
