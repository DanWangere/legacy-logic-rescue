# Legacy Logic Rescue

**Legacy SQL Migration Assurance Platform**

A Microsoft Fabric data engineering project demonstrating how organizations can modernize legacy reporting systems while preserving financial accuracy, validating business rules, and maintaining operational reliability.

## The Business Problem

Organizations often rely on legacy reporting systems containing years of undocumented business logic.

Migrating those systems to modern analytical platforms introduces several risks:

- Business rules may be incorrectly translated.
- Historical financial reports may no longer reconcile.
- Previously hidden reporting defects may be carried into the new system.
- AI-assisted migrations may introduce or overlook important logic.
- Engineering teams may struggle to demonstrate that the new platform produces trustworthy results.

**Legacy Logic Rescue addresses these problems through a controlled, evidence-driven migration process.**

## The Solution

The platform combines Microsoft Fabric, PostgreSQL, Python, PySpark, Delta Lake, GitHub Actions, and Power BI to support legacy reporting modernization.

It provides:

1. Data ingestion and transformation using a Bronze/Silver/Gold architecture.
2. Legacy SQL execution in PostgreSQL.
3. Independent financial reconciliation between legacy and modern reporting systems.
4. AI-assisted business-rule extraction with human review.
5. Automated detection and quantification of reporting discrepancies.
6. Incremental processing, audit logging, and recovery testing.
7. Deployment across isolated Development, Test, and Production environments.
8. Operational monitoring using Microsoft Fabric Real-Time Intelligence.
9. Performance and capacity analysis based on measured workloads.

## Technology Stack

| Area | Technology |
|---|---|
| Data platform | Microsoft Fabric |
| Data ingestion | Fabric Data Factory |
| Storage | OneLake, Delta Lake |
| Data processing | PySpark, Spark SQL |
| Legacy database | PostgreSQL 17 |
| Analytical storage | Fabric Lakehouse and Warehouse |
| Reporting | Power BI, Direct Lake |
| Real-time monitoring | Eventstream, Eventhouse, KQL |
| Continuous Integration | GitHub Actions |
| Deployment | Fabric Deployment Pipelines |
| Development | Python, SQL, Docker |

## Engineering Results

### Data Engineering

- Ingested and processed 50,150,843 historical sales records.
- Implemented Bronze and Silver Delta Lake transformations.
- Verified financial reconciliation between ingestion and transformation layers.
- Implemented incremental Delta Change Data Feed processing.
- Validated checkpointing, audit logging, and controlled failure recovery.

### Legacy Migration Assurance

- Established a frozen PostgreSQL migration baseline containing 250,754 sales records.
- Achieved full parity between trusted PostgreSQL monthly reporting results and the equivalent Fabric implementation.
- Built an automated discrepancy comparison engine.
- Identified and quantified deliberately introduced reporting defects.
- Preserved migration evidence and human-reviewed AI findings.

### AI-Assisted Migration Evaluation

Two controlled SQL benchmarks were analyzed using a blind AI extraction process.

| Metric | Result |
|---|---:|
| Controlled benchmarks | 2 |
| Deliberately seeded defects | 4 |
| Seeded defects identified | 4 |
| Seeded-defect recall | 100% |

These findings demonstrate successful detection within the controlled experiments. They do not establish general AI accuracy. Comprehensive false-positive evaluation remains outstanding.

### CI/CD and Release Management

- Implemented automated PostgreSQL regression testing using GitHub Actions.
- Created a Fabric deployment pipeline spanning Development, Test, and Production.
- Demonstrated controlled notebook and pipeline promotion.
- Verified environment-specific Lakehouse binding.
- Executed validation pipelines in isolated environments.

Native Fabric Git integration and unattended API deployment are not currently configured.

### Operational Reliability

- Implemented audit logging for pipeline execution.
- Built transactional Gold Warehouse refresh procedures.
- Verified automated value-level reconciliation.
- Tested corruption detection and rollback.
- Created a Power BI migration-assurance report and a Real-Time Operations dashboard.

Real-Time Intelligence currently uses synthetic operational events, not live production telemetry.

## Performance and Cost Optimization

Performance experiments demonstrated that optimization decisions must be supported by actual measurements.

Key findings:

- Z-Order reduced Delta files from 10 to 3 but increased selective-query latency in a paired benchmark.
- Spark automatically selected an appropriate broadcast join for the customer dimension.
- Warehouse query times decreased substantially as data became memory-resident.
- F64 trial capacity utilization averaged 0.53%, with a measured peak of 2.85%.
- Eventhouse uptime dominated its measured CU consumption.

F8 and F16 remain potential capacity-sizing candidates requiring representative production testing.

See [Performance & Cost Optimization Case Study](docs/performance-cost-case-study.md).

## Project Documentation

- Architecture: `docs/architecture.md`
- Deployment guide: `docs/deployment-guide.md` (planned)
- Operations runbook: `docs/operations-runbook.md` (planned)
- Data quality and validation: `docs/data-quality.md` (planned)
- Security and governance: `docs/security-governance.md` (planned)
- Performance case study: `docs/performance-cost-case-study.md`

## Project Scope and Limitations

The solution is a simulated consulting engagement using public sample data and synthetic benchmark scenarios.

Development contains the principal end-to-end implementation. Test and Production currently contain selected deployed components, not complete replicas of every Development workload.

The project demonstrates engineering practices and migration assurance methods. It is not presented as a live client production deployment.

## Future Improvements

- Complete Fabric Git integration when tenant authorization is available.
- Automate approved deployments through Fabric REST APIs.
- Expand the AI evaluation with additional blind benchmarks and false-positive scoring.
- Implement live Data Factory telemetry integration.
- Test realistic concurrent workloads on smaller Fabric capacities.
- Complete user-level security enforcement testing.

## Project Objective

Demonstrate how data engineering, AI-assisted analysis, rigorous validation, and operational controls can work together to modernize legacy reporting systems without sacrificing trust in business data.