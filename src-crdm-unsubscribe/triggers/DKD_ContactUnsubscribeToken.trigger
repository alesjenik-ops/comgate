trigger DKD_ContactUnsubscribeToken on Contact (before insert) {
    DKD_UnsubscribeToken.fillContacts(Trigger.new);
}
