trigger DKD_AccountUnsubscribeToken on Account (before insert) {
    DKD_UnsubscribeToken.fillPersonAccounts(Trigger.new);
}
