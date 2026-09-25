# Recording runbook — W02

Everything below is a terminal or a VS Code window. Nothing here needs a browser
except the two optional UI beats.

## Before you press record

```bash
sf org create scratch -f config/project-scratch-def.json -a aip-w02 -d -y 30
sf project deploy start -d force-app/base
sf org assign permset -n AIP_Demo_Operator
sf apex run -f scripts/apex/01-seed.apex
sf project deploy start -d force-app/broken
```

Terminal font at 18pt or larger. Clear the scrollback before each take.

---

## Beat 1 — the three triggers  *(~90s)*

Open, in this order, and scroll slowly:

1. `force-app/broken/main/default/triggers/CatalogueItemTrigger.trigger`
2. `.../ManufacturerListingTrigger.trigger`
3. `.../CaseTrigger.trigger`

The line to land: *three sensible requests, three years apart, none of them wrong
on its own.*

## Beat 2 — the test that proves nothing  *(~45s)*

`BrokenChainTest.cls`. Run it. Green.

```bash
sf apex run test -t BrokenChainTest -w 10 -r human
```

Land: *it inserts one record.*

## Beat 3 — the failure  *(~30s)*

```bash
sf apex run -f scripts/apex/02-break-it.apex
```

Hold on `Too many SOQL queries: 101`. Say the number. Explain that it failed on
item 101 of 200 and committed nothing.

## Beat 4 — the diagram  *(~60s)*

`docs/diagrams.md`, "Before — the cycle". Then the snake-eating-its-own-tail
line, and the point about cyclomatic complexity: one domino, whole org stops.

## Beat 5 — the retire  *(~30s)*

```bash
sf project deploy start --manifest manifest/empty-package.xml \
  --post-destructive-changes manifest/destructive-broken.xml
sf project deploy start -d force-app/fixed
```

Land: *you do not refactor this in place. You route around it and retire it.*

## Beat 6 — the same save  *(~45s)*

```bash
sf apex run -f scripts/apex/03-prove-it.apex
```

`Queries used: 0 / 100`. Pause there. Then:

```bash
sf apex run -f scripts/apex/04-verify.apex
```

## Beat 7 — the three changes  *(~3min)*

Side-by-side in VS Code:

| Left | Right |
|---|---|
| `CatalogueItemTriggerHandler.cls` | `CatalogueItemPublishRepricing.cls` |
| the `hasRun` flag | `ChangeDetector.cls` |
| nothing | `TriggerActionRegistryTest.cls` |

## Beat 8 — the master-detail  *(~90s)*

Setup > Object Manager > Manufacturer Listing > Fields > Catalogue Item. Show
that it is master-detail. Then Catalogue Item > `Listing_Count__c`, the roll-up
that depends on it.

Land: *this is why a one-line schema decision takes a quarter to unwind — and why
you unwind it in four shipping steps, not one big bang.*

Cut to `docs/diagrams.md`, "The remediation order".

## Beat 9 — the close  *(~60s)*

`BulkSafetyTest.cls`. Run it.

```bash
sf apex run test -t BulkSafetyTest -w 20 -r human
```

Land: *write this test on day one and none of the rest of this video happens.*

---

## Optional UI beats

- **The kill switch.** Setup > Permission Sets > AIP Automation Bypass > assign
  to yourself. Save a catalogue item. Nothing fires. Unassign. Two clicks, no
  deployment. Contrast with commenting out a trigger in production.
- **The inbox.** Run `06-staging-demo.apex`, then open the Inbound Listing
  Staging tab and read the Error Message column out loud.

---

## Reset between takes

```bash
sf apex run -f scripts/apex/00-reset.apex
sf apex run -f scripts/apex/01-seed.apex
```
