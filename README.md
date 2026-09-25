# sf-overcoupled-org

Companion Salesforce project for **The Architect in Progress**, episode W02 —
*the data model mistake*. This is the org from the episode. You can deploy it,
break it the same way, and then deploy the rebuild and watch the same save
succeed.

The scenario is invented: a pharmaceutical wholesaler with a product catalogue,
manufacturer listings, and cases raised when prices move. Three triggers written
by three teams over three years form a cycle, and a routine price rise across the
catalogue dies with `Too many SOQL queries: 101`. The rebuild gets the same
outcome at constant query cost, with the cascade cut at a seam and a test that
would have caught the original on day one.

---

## What is in the repository

| Path | Purpose |
| --- | --- |
| `force-app/base` | The data model, demo data factory, and the `AIP_Demo_Operator` permission set. Deploy this first. |
| `force-app/broken` | The three-trigger chain and the test that passes while proving nothing. |
| `force-app/fixed` | The rebuild: metadata-driven trigger dispatch, change detection, a platform-event seam, an idempotency ledger, and a unit of work. |
| `manifest/` | Destructive changes that retire the broken package before the fixed one goes in. |
| `scripts/apex/` | Numbered anonymous Apex scripts. Run them in order to follow the episode. |
| `docs/diagrams.md` | Mermaid diagrams of the cycle and the seam. |

---

## What you need

- A Salesforce Developer Edition org, or a scratch org with a Dev Hub enabled
- Salesforce CLI (`sf`) v2
- VS Code with the Salesforce Extension Pack, optional but handy

---

## Setup

Pick an org and make it the default:

```bash
# scratch org
sf org create scratch -f config/project-scratch-def.json -a aip-w02 -d -y 30

# or a Developer Edition org
sf org login web -a aip-w02 -s
```

Deploy the data model, assign the permission set, and seed the data:

```bash
sf project deploy start -d force-app/base
sf org assign permset -n AIP_Demo_Operator
sf apex run -f scripts/apex/01-seed.apex
```

> **Assign the permission set.** The rebuilt package runs its DML in user mode.
> Without `AIP_Demo_Operator` it refuses to write, which is correct behaviour
> and easy to mistake for a bug.

The seed creates 200 catalogue items with 3 listings each. 200 is not an
arbitrary number. It is the chunk size the platform hands a trigger, and 101 is
the SOQL ceiling. One query per record inside a loop survives a load of 100 and
dies on a load of 200, which is why this class of bug reaches production with a
green test suite behind it.

The same steps are available as npm scripts if you prefer: `npm run org:create`,
`deploy:base`, `assign:perms`, `seed`.

---

## Act one — watch it fall over

```bash
sf project deploy start -d force-app/broken
sf apex run -f scripts/apex/02-break-it.apex
```

Expected:

```text
System.LimitException: Too many SOQL queries: 101
```

Two hundred catalogue items in the save. It failed on number 101. The whole
transaction rolls back, so the operator gets an error, retries, gets the same
error, and has no way to tell how far it got.

Now run the test that ships with the broken package:

```bash
sf apex run test -t BrokenChainTest -w 10 -r human
```

It passes. It covers every line of all three handlers. It inserts one record.
Coverage is not a safety property.

---

## Act two — the rebuild

Retire the chain, deploy the fix, and run the identical save:

```bash
sf project deploy start --manifest manifest/empty-package.xml --post-destructive-changes manifest/destructive-broken.xml
sf project deploy start -d force-app/fixed
sf apex run -f scripts/apex/03-prove-it.apex
```

Expected:

```text
Records saved:  200
Queries used:   0 / 100
DML used:       1 / 150
```

Zero queries. The one DML is the platform event publish. A few seconds later,
in its own transaction with its own limits, the subscriber does the work:

```bash
sf apex run -f scripts/apex/04-verify.apex
```

Run `03-prove-it.apex` a second time and the ledger count does not double.

Then run the test that should have existed from day one:

```bash
sf apex run test -t BulkSafetyTest -w 20 -r human
```

`BulkSafetyTest` asserts that query and DML cost do not change between a
1-record save and a 199-record save. Write that test first and this episode
never happens.

---

## The three changes that matter

Everything else in `force-app/fixed` is plumbing around these.

**1. The static Boolean is gone.** A `hasRun` flag asks *have I run before?*
The question that matters is *did anything I care about change?* `ChangeDetector`
asks that one, so the second pass finds nothing changed and does nothing. That
terminates. A flag does not terminate; it hides, and what it hides is dropped
work that shows up later as a wrong number in a report.

**2. The cascade is cut, not shortened.** `CatalogueItemPublishRepricing`
publishes a platform event and stops. Whatever happens next runs in its own
transaction with its own limits, and if it fails it fails alone instead of
taking the price change down with it. The guarantee against double processing
is a unique index on `Processed_Event__c.Event_Uuid__c`, because at-least-once
delivery is not something a subscriber can promise in code.

**3. The wiring is validated at deploy time.** A metadata-driven dispatcher's
weakness is that the wiring is data, and data is not compiled. Rename a class
and nothing complains until a user saves a record. `TriggerActionRegistryTest`
is thirty lines and fails the deployment instead.

---

## Other things to try

| Script | Shows |
| --- | --- |
| `05-bypass-demo.apex` | Stopping automation without a deployment. Assign the `AIP_Automation_Bypass` permission set, save a record, nothing fires. Unassign it. Two clicks, no deploy. |
| `06-staging-demo.apex` | The inbound inbox. Three rows arrive from a manufacturer feed, one of them malformed. Nothing is rejected; bad rows stay on the inbox with a readable reason. |
| `00-reset.apex` | Wipes the demo data so you can start again. Follow it with `01-seed.apex`. |
| `99-diagnose.apex` | Field-level access diagnostics, if the fixed package refuses to write. |

---

## About the framework

`MetadataTriggerHandler` and `TriggerAction` are deliberately the same shape as
the community **Trigger Actions Framework** (Mitch Spano, Apache-2.0). If you are
shipping to production, install that package rather than copying these files.
It has years of edge cases baked in that this teaching copy does not.

What is here is the minimum needed to see the idea working, plus three gaps the
community version leaves to you, closed on purpose:

| Gap | Closed by |
| --- | --- |
| Triggers run in system mode, so FLS and sharing become a review checklist item | `SecureDb`, user mode by default, system mode named and justified |
| Registry wiring is data, so a rename breaks at runtime | `TriggerActionRegistryTest`, fails the deploy |
| No commit point, so partial saves are normal | `AipUnitOfWork`, one savepoint, declared object order |

If you are already on **fflib**, use `fflib_SObjectUnitOfWork` instead of
`AipUnitOfWork`, but construct it with an `fflib_SObjectUnitOfWork.IDML`
implementation that calls `Database.insert` with `AccessLevel.USER_MODE`. The
stock one does not.

---

## The master-detail

`Manufacturer_Listing__c.Catalogue_Item__c` is still master-detail, on purpose.
It is the constraint the whole episode hangs off. The relationship was made
controlling when it should have been transitional, and by the time anyone
noticed, `Catalogue_Item__c.Listing_Count__c`, a roll-up summary, depended on
it. You cannot simply change it to a lookup. The roll-up has to go first, and
something has to replace it, and that is why a one-line schema mistake takes a
quarter to unwind.

The order of a real remediation is:

1. Cut the cascade with the platform event. No schema change yet. This is the
   part that buys you breathing room.
2. Replace the roll-up with a maintained field, in code, behind the framework.
3. Delete the roll-up.
4. Only now convert master-detail to lookup, with the data already migrated.

Each step ships on its own and each one leaves the org working. You identify
it, isolate it, and fix it incrementally. You do not stop the business for a
rewrite.

---

## Running all tests

```bash
sf apex run test -l RunLocalTests -w 20 -r human
```

---

*Everything here was written from scratch for the video. Nothing is derived from
any client engagement, and no real company or product is depicted.*
