/**
 * Prijima pozadavky na podekovani (platform event). Diky PlatformEventSubscriberConfig
 * DKD_ThankYouRequested_Admin bezi jako spravce, ne jako guest user, ktery event publikoval.
 * Vlastni prace (PDF, e-mail) jde do Queueable, protoze getContentAsPDF v triggeru nejde.
 */
trigger DKD_ThankYouRequestedTrigger on DKD_Thank_You_Requested__e (after insert) {
    DKD_GiftThankYouService.handleRequestedEvents(Trigger.new);
}
