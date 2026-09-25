/**
 * The contract.
 *
 * Every piece of automation in this org implements one of these and nothing else.
 * A class that implements AfterUpdate cannot accidentally be wired into
 * before-insert, because the router will refuse to cast it and say so by name.
 *
 * Design note: this is deliberately the same shape as the community Trigger
 * Actions Framework (Mitch Spano, Apache-2.0). If you are shipping to production,
 * install that package rather than this file - it has years of edge cases baked
 * in that this teaching copy does not. What is here is the minimum needed to see
 * the idea working, plus three gaps the community version leaves open, closed on
 * purpose: user-mode DML, a registry that is validated at deploy time, and a
 * unit of work at the end of the dispatch.
 */
public class TriggerAction {

    public interface BeforeInsert  { void beforeInsert(List<SObject> newList); }
    public interface AfterInsert   { void afterInsert(List<SObject> newList); }
    public interface BeforeUpdate  { void beforeUpdate(List<SObject> newList, Map<Id, SObject> oldMap); }
    public interface AfterUpdate   { void afterUpdate(List<SObject> newList, Map<Id, SObject> oldMap); }
    public interface BeforeDelete  { void beforeDelete(Map<Id, SObject> oldMap); }
    public interface AfterDelete   { void afterDelete(Map<Id, SObject> oldMap); }
    public interface AfterUndelete { void afterUndelete(List<SObject> newList); }
}
