/**
 * Every query in the rebuilt package starts here, which buys three things:
 *
 *   - a field list you can audit in one place instead of grepping for SELECT
 *   - user mode by construction
 *   - a set-based signature, so it is physically awkward to write the one-record
 *     version that becomes the loop
 *
 * Note there is no selectById(Id). Not an oversight.
 *
 * `accessLevel` is public and defaults to user mode. The only caller that raises
 * it is the platform event subscriber, which runs as the Automated Process user
 * and would otherwise be refused - and it says so, in writing, where it does it.
 */
public abstract inherited sharing class SelectorBase {

    public AccessLevel accessLevel = AccessLevel.USER_MODE;

    public abstract SObjectType getSObjectType();
    public abstract List<SObjectField> getFields();

    protected String objectName() {
        return getSObjectType().getDescribe().getName();
    }

    protected String fieldList() {
        List<String> names = new List<String>();
        for (SObjectField f : getFields()) {
            names.add(f.getDescribe().getName());
        }
        return String.join(names, ', ');
    }

    protected String baseQuery() {
        return 'SELECT ' + fieldList() + ' FROM ' + objectName();
    }

    protected List<SObject> run(String soql, Map<String, Object> binds) {
        return SecureDb.query(soql, binds, accessLevel);
    }

    public virtual List<SObject> selectByIds(Set<Id> ids) {
        if (ids == null || ids.isEmpty()) {
            return new List<SObject>();
        }
        return run(baseQuery() + ' WHERE Id IN :ids', new Map<String, Object>{ 'ids' => ids });
    }
}
