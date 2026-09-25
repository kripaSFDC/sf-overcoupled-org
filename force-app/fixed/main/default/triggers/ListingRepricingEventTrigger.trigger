/**
 * The subscriber.
 *
 * Deliberately NOT routed through the metadata handler: platform event records
 * have no Id and no old map, so half the framework's contract does not apply.
 * Pretending otherwise would be cleverness for its own sake.
 */
trigger ListingRepricingEventTrigger on Listing_Repricing__e (after insert) {
    RepricingEventHandler.handle(Trigger.new);
}
