# Diagrams

Paste either block into Obsidian, or into any Mermaid renderer, and screen-record
it. Both are sized to read at 1080p.

## Before — the cycle

```mermaid
flowchart LR
    A["Catalogue Item<br/>after update"] -->|"SOQL in loop<br/>1 query per record"| B["Manufacturer Listing<br/>after update"]
    B -->|"2 more queries<br/>per record"| C["Case<br/>after insert"]
    C -->|"updates the parent"| A
    A -.->|"hasRun = true<br/>second pass silently dropped"| D["Work that never happened"]

    style A fill:#F97316,stroke:#7C2D12,color:#fff
    style B fill:#F97316,stroke:#7C2D12,color:#fff
    style C fill:#F97316,stroke:#7C2D12,color:#fff
    style D fill:#1f2937,stroke:#374151,color:#9ca3af
```

Three arrows on a whiteboard. Four thousand lines in a debug log.

## After — the seam

```mermaid
flowchart LR
    subgraph T1["Transaction 1 &mdash; the user's save"]
        A["Catalogue Item<br/>after update"] --> CD{"ChangeDetector<br/>did the price move?"}
        CD -->|no| STOP["nothing"]
        CD -->|yes| E["publish<br/>Listing_Repricing__e"]
    end

    E ==>|"seam"| S

    subgraph T2["Transaction 2 &mdash; its own limits"]
        S["Subscriber"] --> L{"Processed_Event__c<br/>seen this UUID?"}
        L -->|yes| NOOP["nothing"]
        L -->|no| SVC["CataloguePricingService<br/>4 queries, any batch size"]
        SVC --> UOW["AipUnitOfWork<br/>one savepoint"]
        UOW --> OUT["Listings + Cases + ledger row"]
    end

    style A fill:#F97316,stroke:#7C2D12,color:#fff
    style E fill:#F97316,stroke:#7C2D12,color:#fff
    style S fill:#0ea5e9,stroke:#075985,color:#fff
    style SVC fill:#0ea5e9,stroke:#075985,color:#fff
    style UOW fill:#0ea5e9,stroke:#075985,color:#fff
```

## The remediation order

```mermaid
flowchart TD
    S1["1. Cut the cascade<br/><small>platform event &mdash; no schema change</small>"]
    S2["2. Replace the roll-up<br/><small>maintained field behind the framework</small>"]
    S3["3. Delete the roll-up<br/><small>the dependency that blocked everything</small>"]
    S4["4. Master-detail to lookup<br/><small>data already migrated</small>"]
    S1 --> S2 --> S3 --> S4

    S1 -.-> N1["org still works"]
    S2 -.-> N2["org still works"]
    S3 -.-> N3["org still works"]
    S4 -.-> N4["org still works"]

    style S1 fill:#F97316,stroke:#7C2D12,color:#fff
    style S2 fill:#F97316,stroke:#7C2D12,color:#fff
    style S3 fill:#F97316,stroke:#7C2D12,color:#fff
    style S4 fill:#F97316,stroke:#7C2D12,color:#fff
```

Each step ships on its own. Nobody stops.
