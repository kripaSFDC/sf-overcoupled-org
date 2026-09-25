/**
 * What replaces `private static Boolean hasRun`.
 *
 * The static flag was answering the wrong question. It asked "have I run before?"
 * when the question that matters is "did anything I care about actually change?"
 *
 * Ask the right question and recursion stops being a problem you manage. The
 * second pass finds nothing changed and does nothing - not because a flag
 * blocked it, but because there is genuinely nothing to do. That terminates.
 * A flag does not terminate; it hides.
 */
public inherited sharing class ChangeDetector {

    public static Boolean hasChanged(SObject current, SObject prior, Set<SObjectField> watched) {
        if (prior == null) {
            return true;
        }
        for (SObjectField f : watched) {
            if (current.get(f) != prior.get(f)) {
                return true;
            }
        }
        return false;
    }

    /**
     * Returns only the records where a watched field moved. Everything downstream
     * takes this list, so a 200-record save where two prices changed does two
     * records of work.
     */
    public static List<SObject> changed(List<SObject> newList, Map<Id, SObject> oldMap, Set<SObjectField> watched) {
        List<SObject> out = new List<SObject>();
        for (SObject current : newList) {
            SObject prior = (oldMap == null) ? null : oldMap.get((Id) current.get('Id'));
            if (hasChanged(current, prior, watched)) {
                out.add(current);
            }
        }
        return out;
    }

    public static Set<Id> changedIds(List<SObject> newList, Map<Id, SObject> oldMap, Set<SObjectField> watched) {
        Set<Id> ids = new Set<Id>();
        for (SObject s : changed(newList, oldMap, watched)) {
            ids.add((Id) s.get('Id'));
        }
        return ids;
    }
}
