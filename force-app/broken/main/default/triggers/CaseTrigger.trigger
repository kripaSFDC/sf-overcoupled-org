/**
 * Link 3 of 3, and the one that closes the circle.
 *
 * Year three. Someone wanted the catalogue item flagged when a case was open
 * against it, so the merchandising team could see it in a list view. One field.
 * That is how the loop got made: three sensible requests, three years apart,
 * none of them wrong on its own.
 */
trigger CaseTrigger on Case (after insert) {
    CaseTriggerHandler.onAfterInsert(Trigger.new);
}
