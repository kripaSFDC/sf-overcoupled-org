# sf-overcoupled-org

Companion Salesforce project for **The Architect in Progress**, episode W02 —
*the data model mistake*. Everything on screen in that episode comes from this
repository.

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
| `force-app/base` | The data model, demo data factory, and the `AIP_Demo_Operator` permission set. Deploy first. |
| `force-app/broken` | The three-trigger chain and the test that passes while proving nothing. Act one. |
| `force-app/fixed` | The rebuild: metadata-driven trigger dispatch, change detection, platform-event seam, idempotency ledger, unit of work. Act two. |
| `manifest/` | Destructive changes that retire the broken package before the fixed one goes in. |
| `scripts/apex/` | Numbered anonymous Apex scripts, one per beat of the video. |
| `demo-test.bat` | Paced terminal driver for recording. Types commands at a human rhythm and holds for the camera. |
| `docs/recording-runbook.md` | The beat-by-beat shooting order with timings. |
| `docs/diagrams.md` | Mermaid diagrams of the cycle and the seam, sized for 1080p. |

---

## What you need

- A Salesforce Developer Edition org, or a scratch org with a Dev Hub enabled
- Salesforce CLI (`sf`) v2
- Windows for `demo-test.bat`. Every command inside it is a plain `sf` call, so on
  macOS or Linux run those directly.

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

The seed creates 200 catalogue items with 3 listings each. 200 is the chunk size
the platform hands a trigger, and 101 is the SOQL ceiling. That is why one query
per record survives a load of 100 and dies on a load of 200.

The same steps are available as npm scripts (`npm run org:create`,
`deploy:base`, `assign:perms`, `seed`) if you prefer.

---

## How the video is shot

The full shooting order, with timings and the line to land on each beat, is in
[docs/recording-runbook.md](docs/recording-runbook.md). The terminal beats are
driven by `demo-test.bat` so nothing is typed by hand on camera.

### Act one — watch it fall over

```bash
sf project deploy start -d force-app/broken
sf apex run -f scripts/apex/02-break-it.apex
```

Expected:

```
System.LimitException: Too many SOQL queries: 101
```

It failed on item 101 of 200 and committed nothing. Then run
`BrokenChainTest`. It passes, covers every line of all three handlers, and
inserts one record. Coverage is not a safety property.

### Act two — the rebuild

Retire the chain, deploy the fix, run the identical save:

```bash
sf project deploy start --manifest manifest/empty-package.xml --post-destructive-changes manifest/destructive-broken.xml
sf project deploy start -d force-app/fixed
sf apex run -f scripts/apex/03-prove-it.apex
```

Expected:

```
Records saved:  200
Queries used:   0 / 100
DML used:       1 / 150
```

The one DML is the platform event publish. A few seconds later, in its own
transaction, the subscriber does the work:

```bash
sf apex run -f scripts/apex/04-verify.apex
```

Run `03-prove-it.apex` a second time and the ledger count does not double.

### The close

```bash
sf apex run test -t BulkSafetyTest -w 20 -r human
```

`BulkSafetyTest` asserts that query and DML cost do not change between a
1-record save and a 199-record save.

---

## Running the demo driver

`demo-test.bat` runs the on-camera terminal shots with a typed-out prompt and
timed pauses. Run it from the project root against the default org, after the
setup above and with the right package deployed for the shot.

```text
demo-test.bat break    runs 02-break-it, dies at SOQL 101              (broken deployed)
demo-test.bat prove    runs 03-prove-it, prints Queries used: 0 / 100  (fixed deployed)
demo-test.bat test     runs BulkSafetyTest                             (fixed deployed)
demo-test.bat all      break then prove, back to back
demo-test.bat reset    wipes and reseeds between takes. Off camera.
```

Start the recording, then run the script. It sets the console to 120 columns by
30 lines so the terminal fills the frame.

### Reset between takes

```bash
sf apex run -f scripts/apex/00-reset.apex
sf apex run -f scripts/apex/01-seed.apex
```

Or `demo-test.bat reset`, which does both.

---

## The three changes that matter

Everything else in `force-app/fixed` is plumbing around these.

**1. The static Boolean is gone.** A `hasRun` flag asks *have I run before?*
The question that matters is *did anything I care about change?* `ChangeDetector`
asks that one, so the second pass finds nothing changed and does nothing. That
terminates. A flag hides dropped work that shows up later as a wrong number.

**2. The cascade is cut, not shortened.** `CatalogueItemPublishRepricing`
publishes a platform event and stops. Whatever happens next runs in its own
transaction with its own limits. The guarantee against double processing is a
unique index on `Processed_Event__c.Event_Uuid__c`, because at-least-once
delivery is not something a subscriber can promise in code.

**3. The wiring is validated at deploy time.** A metadata-driven dispatcher's
weakness is that the wiring is data, and data is not compiled.
`TriggerActionRegistryTest` fails the deployment when a registered class does
not exist, instead of failing when a user saves a record.

---

## Other demos

| Script | Shows |
| --- | --- |
| `05-bypass-demo.apex` | Stopping automation without a deployment, by permission set |
| `06-staging-demo.apex` | The inbound inbox: bad rows become readable data instead of failed saves |
| `99-diagnose.apex` | Field-level access diagnostics if the fixed package refuses to write |

---

## About the framework

`MetadataTriggerHandler` and `TriggerAction` are deliberately the same shape as
the community **Trigger Actions Framework** (Mitch Spano, Apache-2.0). If you are
shipping to production, install that package rather than copying these files.
This is a teaching copy with three gaps closed on purpose:

| Gap | Closed by |
| --- | --- |
| Triggers run in system mode | `SecureDb`, user mode by default |
| Registry wiring breaks at runtime after a rename | `TriggerActionRegistryTest`, fails the deploy |
| No commit point, so partial saves are normal | `AipUnitOfWork`, one savepoint |

---

## The master-detail

`Manufacturer_Listing__c.Catalogue_Item__c` is master-detail on purpose, and
`Catalogue_Item__c.Listing_Count__c` is a roll-up summary that depends on it.
That is why it cannot simply become a lookup. Leave it in place while filming.
The remediation order is:

1. Cut the cascade with the platform event. No schema change yet.
2. Replace the roll-up with a maintained field behind the framework.
3. Delete the roll-up.
4. Convert master-detail to lookup with the data already migrated.

Each step ships on its own and leaves the org working.

---

## Running all tests

```bash
sf apex run test -l RunLocalTests -w 20 -r human
```

---

*Everything here was written from scratch for the video. Nothing is derived from
any client engagement, and no real company or product is depicted.*
