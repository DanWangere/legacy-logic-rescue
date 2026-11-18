# Legacy Logic Rescue
## Microsoft Fabric Performance & Capacity Optimization

**Project:** Legacy SQL Migration Assurance  
**Platform:** Microsoft Fabric  
**Environment:** FTL64 Trial Capacity  
**Workload:** Wide World Importers sample data and synthetic migration telemetry

### Executive Summary

Legacy Logic Rescue is a migration-assurance platform built using Microsoft Fabric, PostgreSQL, Delta Lake, Data Factory, Eventhouse and Power BI.

The objective of this assessment was to identify opportunities to improve query performance and reduce compute consumption without compromising financial reconciliation accuracy.

The performance investigation found that common optimization techniques did not always improve execution times. In particular, Z-Order increased latency for the tested selective query, while Spark already selected an appropriate broadcast join automatically.

Capacity Metrics showed low overall utilization, suggesting that a smaller Fabric SKU may be suitable for some deployment scenarios. This remains a hypothesis pending workload and concurrency validation.

### 1. Delta Lake Optimization

**Dataset:** 50,150,843 sales records.

A laboratory copy of the Silver sales table was optimized using:

```sql
OPTIMIZE dbo.fact_sale_perf_lab
ZORDER BY (invoice_month, CustomerKey);
```

| Measurement | Before | After |
|---|---:|---:|
| Active Delta files | 10 | 3 |
| Paired query median | 0.4876s | 0.7525s |
| Financial correctness | Passed | Passed |

The optimization took approximately 106 seconds.

**Finding:** Although active file count decreased by 70%, query performance deteriorated by approximately 54% in the paired experiment.

**Decision:** Do not apply Z-Order routinely to this workload without evidence of improved data skipping and acceptable compute cost.

### 2. Spark Join Optimization

A 50.15-million-row sales fact table was joined with a 403-row customer dimension.

The experiment compared Spark's automatic join strategy against an explicitly requested broadcast join.

| Metric | Automatic | Forced broadcast |
|---|---:|---:|
| Median execution time | 0.0431s | 0.0367s |
| Join operator | BroadcastHashJoin | BroadcastHashJoin |
| Financial reconciliation | Passed | Passed |

Both plans already used the appropriate broadcast join strategy. The small measured difference was not sufficient to establish a meaningful performance advantage, particularly given likely execution reuse and caching.

**Decision:** Prefer Spark's automatic optimizer for this workload.

### 3. Warehouse Query Performance

A selective Warehouse query calculated January revenue for unknown customers.

| Run | Duration | Remote storage read | Memory read |
|---|---:|---:|---:|
| 1 | 4,178ms | 84.396 MB | 0 MB |
| 2 | 493ms | 36.659 MB | 47.736 MB |
| 3 | 154ms | 0 MB | 84.396 MB |
| 4 | 150ms | 0 MB | 84.396 MB |

All runs shared the same query hash. The result-cache indicator remained zero.

**Finding:** The progression from remote storage reads to memory-resident reads corresponded with substantially lower execution times.

**Decision:** Separate cold and warm performance measurements. Do not attribute cache-related improvements to SQL optimization.

### 4. Fabric Capacity Assessment

Capacity Metrics were examined across a 14-day observation window.

| Metric | Observed result |
|---|---:|
| Capacity | FTL64 |
| Average utilization | 0.53% |
| Peak utilization | 2.85% |
| Total observed consumption | Approximately 469,112 CU-seconds |
| Significant throttling | None observed |

The Silver transformation notebook was the largest individual consumer, recording approximately 142,590 CU-seconds.

These measurements include development and experimentation, rather than a controlled production workload.

**Assessment:** F64 has substantial unused capacity under the observed conditions. F8 and F16 are candidates for further evaluation, not verified production recommendations.

### 5. Eventhouse Cost Investigation

The Eventhouse's operation-level breakdown reported approximately 61,577 CU-seconds, almost entirely associated with EventHouse UpTime.

Its Capacity Planner was confirmed disabled, with no scheduled always-on minimum configured.

**Finding:** Eventhouse compute consumption is influenced by active runtime, not simply the number of ingested events.

**Decision:** Keep Capacity Planner disabled for the current demonstration. For clients requiring occasional audit reporting rather than low-latency event processing, evaluate scheduled Warehouse reporting as an alternative.

### 6. Capacity Sizing Recommendations

A production sizing exercise should account for scheduled batch jobs, peak concurrency, ingestion frequency, Eventhouse availability requirements, dashboard users, Power BI licensing and required processing deadlines.

F8 and F16 are candidate configurations for smaller deployments. Their suitability must be established using representative execution and concurrency tests.

No final paid-capacity recommendation or monetary savings estimate is asserted from the F64 trial results alone.

### 7. Limitations

This assessment was performed primarily on trial capacity using public sample data and synthetic operational telemetry.

Short query timings can be influenced by caching, concurrent compute usage and platform optimizations.

The 14-day capacity window contains exploratory development activity. It is not a normalized production workload.

Financial amounts and record counts were validated during query experiments, but complete cost attribution and service-level testing remain future work.

### 8. Final Engineering Recommendation

Legacy Logic Rescue should prioritize correctness, reliability and measured workload performance before applying physical storage optimizations or increasing compute capacity.

The experiments demonstrated that reducing file count does not guarantee faster reads, explicit optimizer hints can be unnecessary, and caching can dominate repeated-query benchmarks.

Capacity optimization should be driven by representative production usage, throughput requirements, concurrency and total operating cost.

**Overall assessment:** The platform is technically functional and suitable for further operational validation. Production right-sizing remains open pending representative workload testing.