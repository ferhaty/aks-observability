# AKS observability examples

Companion configuration for **Observability on Azure AKS: Metrics, Logs and Traces** by Ferhat Yildiz / Turing Technology Services. [Turing Technology Services blog](https://blog.turingts.com/).

This builds the monitoring layer for an **existing managed-identity AKS cluster and existing Terraform CI/CD process**. It does not create a second cluster, an Azure Managed Grafana service or a new pipeline.

- **Metrics:** native AKS `ama-metrics` → managed Prometheus in a newly created Azure Monitor workspace → Grafana Community Edition on AKS.
- **Logs:** native Container insights / `ama-logs` → a complete ContainerInsights DCR and AKS association → `ContainerLogV2` in a newly created Log Analytics workspace.
- **Traces:** upstream Podinfo → OTLP/gRPC → traces-only Collector → native Azure OTLP HTTP/protobuf DCE/DCR → `OTelSpans` in the same Log Analytics workspace, associated with the new Application Insights resource.

The Collector and Grafana receive separate user-assigned identities, exact service-account federations and scoped Azure roles. URLs and identities flow from resource outputs to Helm; no hand-copied DCR IDs, client IDs or endpoints.

## Ownership and prerequisites

The normal path creates the taught observability resources in the **existing AKS owner's state**. Only Collector/Grafana Helm releases use the supplementary `example/observability` state. Existing backend reuse is optional: use the established backend with a **distinct state key**, or another approved backend. Never point both roots at the same state.

You need an existing managed-identity AKS cluster, Linux amd64 capacity, the existing cluster Terraform root and CI/CD identity, authorized Kubernetes access, and approval for `observability` and `demo` namespaces. The existing root must be compatible with AzureRM **5.12.0**; upgrading an older provider/cluster module is a separate reviewed change. Preserve its existing cluster resource address, network/node settings and lifecycle protection. Do not apply the mock fixture as a real cluster.

The pipeline must be allowed to create monitoring resources, identities/federations and role assignments in the approved resource group, and update the existing AKS resource. Contributor alone is insufficient for Azure role assignments; use an appropriately scoped RBAC administration permission. Helm also needs separate Kubernetes permissions. Resource-provider registration stays with the subscription owner: native onboarding documents `Microsoft.ContainerService`, `Microsoft.Insights`, `Microsoft.AlertsManagement` and `Microsoft.Monitor`; this module also uses `Microsoft.OperationalInsights` and `Microsoft.ManagedIdentity`. No `Microsoft.Dashboard` resource is deployed.

**This is new monitoring onboarding, not automatic migration of shared monitoring.** Before adding it, inspect AKS add-ons, DCR associations and both shared agent ConfigMaps. If they already serve other workloads, stop and reconcile ownership: retain/reuse the existing destinations or intentionally migrate/adopt their complete rules in the owning state. Do not attach a second log collection rule, overwrite a shared scrape ConfigMap or silently repoint the cluster to a fresh LAW. Reuse is an optional, reviewed adaptation, not a prerequisite to provision all backends in this example.

### Native OTLP status, region and feature checks

Microsoft's newer [OpenTelemetry options overview](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/opentelemetry-options) explicitly calls the **OpenTelemetry Collector route generally available**, while the older [collection/experience overview](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/collect-use-observability-data) still labels its combined feature preview. The separate **AMA and AKS application-monitoring add-ons remain preview** in the newer overview. This example uses the direct Collector route, not those add-ons.

Follow the [direct Collector manual-orchestration guide](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/opentelemetry-protocol-ingestion): create a regular workspace-based Application Insights component, leave automatic OTLP provisioning **Off**, and associate it through the DCR's documented `references.applicationInsights`, `enrichWithReference` and `replaceResourceIdWithReference`. Do not add an invented Application Insights `otlpEnabled` field or switch on portal onboarding afterwards.

The direct Collector guide does **not** give an authoritative region list or require the AKS `AzureMonitorAppMonitoringPreview` feature. The [AKS add-on page](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-open-protocol) documents that flag and its own regional exclusions; do not transfer them to this architecture. Confirm native DCE/DCR OTLP availability, Application Insights experience availability and your service policy in the intended subscription/region. No preview features are registered by this code.

Use one Azure public-cloud region for AKS and the new resources. Public authenticated ingestion/query endpoints are enabled; existing egress, DNS, TLS access to Azure/Entra and registry access are prerequisites. This is **not** a Private Link/AMPLS, sovereign-cloud or cross-region example. Grafana downloads its pinned plugin during startup; restricted networks require an approved mirror or preinstalled image. No resource availability, token exchange, Azure ingestion, KQL or portal experience was tested against Azure.

## Files

| Path | Purpose |
| --- | --- |
| `example/modules/azure-monitor/` | Complete Azure resources: AMW, LAW, Application Insights, two DCEs, three DCRs, two native AKS associations, two dedicated identities/federations/role grants. No AKS resource. |
| `example/owner/` | Integration into the existing owner root, matching AKS properties and provider requirements. Not another deployable cluster root. |
| `example/observability/` | Helm-only root, values templates, provider lock and mock tests. Uses generated owner output plus authorized kubeconfig path/context. |
| `tests/owner-fixture/` | **Mock-only** complete AKS owner stand-in: checks the real dependency graph and output → Helm propagation. Never run ordinary plan/apply here. |
| `example/native/`, `example/podinfo/`, `example/queries/` | One native scrape job, pinned Podinfo workload, PromQL and native-schema KQL. |
| `example/steps/` | Bounded article command snippets. Read individual steps; do not execute the directory as a deployment script. |

Azure Monitor can also create its own default workspace-managed DCR/DCE. Those service-managed resources are not a second Podinfo scrape; this code attaches only its cluster-specific native metrics rule. The ContainerInsights rule deliberately collects **only ContainerLogV2**, not the full inventory/performance stream set for every Container insights dashboard. It retains debug request-start events with `transform_kql = "source"`. Shared agent stderr settings still govern collection; `namespaceFilteringMode` is not a ContainerLogV2 namespace filter.

## Integrate and deploy through the existing pipeline

1. Place `example/modules/azure-monitor` in the owner's source tree. Merge `owner/providers.tf.example` and `owner/monitoring.tf.example` into the **existing AKS root**, adapting the module source path and existing resource/variable names. Supply `monitoring_name`, the approved same-region `location`, subscription/tenant inputs already used by that root. Let its normal `terraform init` update its existing lock; do not overwrite that lock with this repository's standalone test locks.
2. Merge `owner/aks-monitoring.hcl` **inside the existing AKS resource**. It enables managed metrics, MSI Container insights, OIDC and Workload ID. Its LAW reference is to the new module output. Nothing imports or declares AKS in the supplementary root. Do not use `az aks update` behind Terraform's back. Avoid module-wide `depends_on`: AKS depends on LAW, whereas federations/associations depend on AKS outputs. The graph is intentionally resource-specific.
3. Review the owner's plan in the existing CI/CD process: new backends/identity resources and in-place monitoring properties, **no AKS replacement** and no unrelated destination/association changes. Apply only through that process. Inspect the actual resources/associations with `steps/01-inspect.sh`, and inspect the full trace DCR via its generated ID. The AKS native add-ons manage their own ingestion identity; the Microsoft native onboarding templates do not require a blanket Publisher grant to the cluster. The direct Collector's new trace-DCR-scoped Publisher grant is separate.
4. Export the owner's explicit output as the supplementary root's generated input. Set absolute `OWNER_ROOT` and `EXAMPLE_ROOT` and run `steps/00-owner-output.sh` after the owner apply. It calls `terraform output -json observability_inputs`; that output already has the `{environment: ...}` shape. Use a protected pipeline artifact (or equivalent direct pipeline output handoff), not copied endpoint strings. Regenerate on every monitoring change. It contains resource configuration, not a kubeconfig or token. Do not export the whole state.
5. The namespace owner confirms whether `observability` exists; if absent, `steps/00-namespace.sh` creates it and refuses to replace an existing namespace. Create `grafana-admin` only if absent using `steps/10-grafana-secret.sh`, which reads owner-approved local user/password files. Keep their contents out of Git, Terraform inputs/state and shell tracing. Use `admin.existingSecret`; the Grafana login is not an Azure credential.
6. Supply only `kubeconfig_path` and `kubeconfig_context` (and an alternate Secret name if needed), as shown in `observability/terraform.tfvars.example`. Configure its approved backend with a **distinct state key**. Review/apply this Helm-only root through the existing pipeline after the owner output handoff and Secret creation. Inspect Collector/Grafana with steps 04, 11 and 12. Federation/RBAC ordering does not eliminate propagation delay; inspect export/query failures and retry verification after propagation rather than giving broader roles.
7. From `example/`, merge the native Podinfo scrape job via its ConfigMap owner (steps 02/03). One Service target means one Podinfo replica. No annotation scrape, PodMonitor, ServiceMonitor or Collector metrics receiver for the same endpoint. Check `container-azm-ms-agentconfig` retains stderr for `demo`; do not replace a shared policy wholesale.
8. Apply Podinfo using step 05. Keep its local port-forward in a separate terminal (06), then run bounded traffic (07). Use Grafana for PromQL, LAW Logs for `queries/logs.kql`, and the unchanged trace ID in `queries/traces.kql` against **OTelSpans**, not AppTraces.

**Keep Podinfo private and credential-free.** Its diagnostic and fault endpoints are not production endpoints. The Collector's in-cluster gRPC receiver is unauthenticated; enforce network policy before exposing it to untrusted clients. Grafana is single-replica/ephemeral and reachable through a loopback port-forward. UI-created dashboards/users can disappear on Pod replacement; production persistence, availability and access policy are separate decisions.

## Application Insights investigation

The DCR assigns the new Application Insights resource to incoming native spans. Microsoft documents **Search** and **Transaction details** for OTel investigation; use a trace sample there if the experience is available for your resource, with LAW `OTelSpans` as the explicit lookup in this exercise. We did not verify that portal experience live. This is not classic AppRequests/AppTraces ingestion.

Do not expect a complete Application Insights Performance/Failures dashboard or prebuilt OTLP metric queries from this example. Microsoft says those experiences expect **delta OTLP metrics and exponential histograms**. Podinfo's Prometheus histogram remains on the native Prometheus path, and the Collector exports **only traces**. Adding a second metrics pipeline merely to populate a UI would violate this example's single-owner design. No automatic Grafana log-to-trace link is provisioned.

## Pins and offline checks

Terraform `>= 1.10.0, < 2.0.0`; tested here with **1.17.1**. AzureRM **5.12.0**, AzAPI **2.13.0**, Helm provider **3.3.0**. Collector chart/contrib **0.176.1 / 0.162.0**. Grafana community chart/OSS image **14.0.1 / 13.2.4-distroless**, Azure Prometheus plugin **1.0.10**. Podinfo **6.9.2**, image digest pinned in YAML. These are tested pins, not an instruction to upgrade a cluster blindly.

From the repository root, without cloud credentials:

```sh
terraform fmt -check -recursive
for root in example/modules/azure-monitor example/observability tests/owner-fixture; do
  terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$root" validate
  terraform -chdir="$root" test
done
python3 -m unittest discover -s tests -v
for file in example/steps/*.sh; do bash -n "$file" || exit; done
```

`init` only resolves modules/providers. `terraform test` uses mock providers and explicit overrides for the nested Helm releases; its `command = apply` is a **mock graph evaluation**, not permission to run real `terraform apply`. The full owner fixture catches dependency cycles and propagation from created workspace/DCR/identity outputs through AKS to Helm values. Negative controls reject an HTTP issuer/endpoint, an Application Insights connection string in place of OTLP and a shared Collector/Grafana identity.

Locally verified: fmt, backend-disabled init, validate, mock graph tests, both pinned chart renders/lints, Kubernetes schemas with invalid-spec controls, actual Collector configuration parser with invalid queue-size control, and actual pinned Podinfo → Collector gRPC → loopback HTTP/protobuf with matching log/span TraceId. **No Azure provisioning or deployment occurred.** Local checks do not establish Azure permissions, API acceptance, token exchange, webhook mutation, native-agent ingestion, KQL or managed service availability. The local HTTP sink is not Azure.

## Cleanup and data ownership

Stop port-forwards and delete only the named Podinfo Deployment/Service (step 09). Remove only its added scrape job, preserving all unrelated jobs. Destroy the **Helm-only supplementary root** through its owner before deleting the exclusive Grafana Secret (optional step 13). Keep namespaces used by other workloads.

Backends, native agent associations and federated identities remain in the **AKS owner's state**. Keep them if monitoring continues. To retire this monitoring stack completely, first remove dependent workloads/Helm, then review the cluster owner's in-place removal of the monitoring add-on blocks and associations. Only after collection is detached, retention/export obligations are satisfied and every consumer is checked should that owner remove dedicated DCRs/DCEs, identity grants/federations, Application Insights, LAW and AMW. A workspace deletion destroys retained telemetry. Never run `terraform destroy` on the whole AKS owner root, delete a shared resource group, or remove OIDC/Workload ID used by others. This is staged resource ownership, not a blanket cleanup command.

## Source of the native OTLP ARM shape

The trace DCR is a narrowed implementation of [Microsoft's documented manual-orchestration template](https://github.com/microsoft/AzureMonitorCommunity/blob/67ecd88b374a71e4b5701d81e7ef5f53cdf71dc9/Azure%20Services/Azure%20Monitor/OpenTelemetry/OTLP_DCE_DCR_ARM_Template.txt). It keeps `directDataSources.otelTraces`, all three trace streams, the LAW destination and Application Insights references/enrichment. It removes the AMA `dataSources`, direct logs/metrics and their destinations/flows. Both resources use `2024-03-11`; the Collector URL combines the DCE **logs ingestion endpoint** and DCR **immutable ID** returned by Azure. AzAPI schema validation stays enabled. Native ARM API fields are sourced, but local mocks do not prove service acceptance.

## Upstream software and licensing

Podinfo is the upstream project by Stefan Prodan and contributors, not an application implemented by this repository. [Podinfo 6.9.2's licence](https://github.com/stefanprodan/podinfo/blob/6.9.2/LICENSE) is Apache-2.0 and retains `Copyright 2018 Stefan Prodan. All rights reserved.` This repository references its released container image; it does not vendor the application source or binary. Helm charts, Collector, Grafana and plugins remain separate upstream software with their own licences and notices.

No blanket licence has been selected for this repository's own example files. The upstream Podinfo licence does not automatically license these configuration examples.

## References

- [Azure Kubernetes monitoring onboarding](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable)
- [Azure Monitor native OTLP ingestion](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/opentelemetry-protocol-ingestion)
- [Grafana authentication for Azure managed Prometheus](https://learn.microsoft.com/en-us/azure/azure-monitor/metrics/prometheus-grafana)
- [OpenTelemetry Helm charts](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Grafana community Helm charts](https://github.com/grafana-community/helm-charts)
