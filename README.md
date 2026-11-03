# AKS observability examples

Companion configuration for **Observability on Azure AKS: Metrics, Logs and Traces** by Ferhat Yildiz / Turing Technology Services. [Turing Technology Services blog](https://blog.turingts.com/).

Build the monitoring layer for an existing managed-identity AKS cluster using its established Terraform CI/CD process:

- **Metrics:** native `ama-metrics` → managed Prometheus in a new Azure Monitor workspace → Grafana Community Edition on AKS.
- **Logs:** native Container insights / `ama-logs` → a new ContainerInsights DCR and AKS association → `ContainerLogV2` in a new Log Analytics workspace.
- **Traces:** Podinfo → OTLP/gRPC → traces-only Collector → native Azure OTLP HTTP/protobuf DCE/DCR → `OTelSpans` in the same Log Analytics workspace, linked to new Application Insights.

## One observability configuration

`example/observability/` creates **all new monitoring resources and both Helm releases**. Helm receives endpoints and client IDs directly from those resources. The Collector gets trace-DCR-scoped write access; Grafana gets workspace-scoped read access through a different federated identity. No generated input file or separate Helm state is needed.

`example/observability/` groups the additions to your existing Terraform setup; it does not require a new deployment or state. Keep the **existing AKS resource** in its existing configuration rather than declaring it again. The supplied example reads selected ARM properties through AzAPI without retrieving cluster credentials. Its commands show that configuration separately; when integrating with existing code, adapt the paths and references to that code.

| Path | Purpose |
| --- | --- |
| `example/observability/` | AMW, LAW, Application Insights, DCEs/DCRs/associations, dedicated identities/federations/RBAC and Collector/Grafana Helm releases. |
| `example/aks-settings/` | Small snippets to merge into the existing AKS configuration; not a deployable root. |
| `example/native/`, `example/podinfo/`, `example/queries/` | One native scrape job, pinned upstream Podinfo, PromQL and native-schema KQL. |
| `example/steps/` | Individual article commands; not a script to run wholesale. |

## Prerequisites

Use an existing managed-identity AKS cluster with Linux amd64 capacity, OIDC and Workload Identity enabled, and existing configured AzureRM, AzAPI and Helm providers for that same cluster in the existing pipeline. The observability root checks those identity settings before proceeding. If needed, merge `aks-settings/identity.hcl` inside the existing AKS resource and apply that configuration first. Preserve its resource address and unrelated settings; check snippet compatibility with its provider/module rather than blindly upgrading it.

Integrate these additions into the Terraform root that already has your configured providers. If you run `example/observability/` separately, reuse or adapt that configuration there (for example, in an untracked `providers.tf`); providers are not inherited from another folder or state. `versions.tf` retains the required provider packages and versions, not authentication configuration. The Azure providers must use the intended subscription/tenant, and Helm must target the same AKS cluster. With resource providers registered separately, retain `resource_provider_registrations = "none"` for AzureRM and `skip_provider_registration = true` and `enable_preflight = false` for AzAPI. This guide does not choose an AKS authentication method. The shell steps use existing working kubectl access; `KUBE_CONTEXT` selects the intended cluster for those commands, not Terraform provider authentication.

The pipeline needs Azure permissions to create the monitoring resources, identities/federations and scoped role assignments, and Kubernetes permissions for Helm. Contributor alone cannot create role assignments. Updating the AKS settings uses the existing cluster deployment permissions. Register the required resource providers through the existing subscription setup: `Microsoft.ContainerService`, `Microsoft.Insights`, `Microsoft.AlertsManagement`, `Microsoft.Monitor`, `Microsoft.OperationalInsights` and `Microsoft.ManagedIdentity`. This example creates no managed Grafana resource.

Use one Azure public-cloud region, derived from AKS, for the new monitoring resources. Check native OTLP and Application Insights availability in that region/subscription. This is public authenticated ingestion/query, not Private Link/AMPLS, sovereign-cloud or cross-region networking. The pipeline needs access to the Kubernetes API and registries; workloads need Azure/Entra, image and Grafana plugin-catalog access. Restricted networks need an approved mirror or preinstalled plugin image.

This is **new monitoring onboarding**, not migration of an existing shared installation. Inspect AKS add-ons, DCR associations and shared agent ConfigMaps with `steps/01-inspect.sh` before changing them. If monitoring is already configured, reconcile its destinations/rules first; do not add duplicate collection paths or silently repoint shared logs to a fresh workspace.

## Apply the supplied example in this order

1. Ensure the existing AKS configuration has OIDC and Workload Identity enabled as above. Confirm the `observability` namespace and Grafana admin Secret: `steps/00-namespace.sh` and `steps/10-grafana-secret.sh` create them only if absent. Use approved local credential files; keep their contents out of Git, Terraform and shell tracing. The Secret is for Grafana login, not Azure authentication.
2. With the existing provider configuration in this root, fill in `observability/terraform.tfvars.example` through the pipeline's normal input mechanism. Initialize, review and apply the **complete observability root**. It reads the existing cluster, creates the monitoring resources and native associations, and installs Collector/Grafana after their federations and role assignments. No AKS mutation is in this plan. The native associations alone do not enable collection.
3. Read the new workspace ID with `terraform -chdir=example/observability output -raw log_analytics_workspace_id`. Pass that one value as `observability_log_analytics_workspace_id` to the existing AKS configuration. Add `aks-settings/variables.tf.example` and merge `aks-settings/monitoring.hcl` inside its existing cluster resource. Review and apply this in-place change through its normal pipeline: it enables managed metrics and MSI Container insights. Keep the already-enabled OIDC/Workload Identity settings. Do not use CLI/portal onboarding in parallel, which can create another set of rules or destinations.
4. Inspect the actual add-ons and DCR associations with step 01 and check Collector/Grafana rollouts with steps 04 and 12. A successful Terraform apply does not eliminate federation/RBAC propagation time. Diagnose export/query failures without broadening roles. Until the AKS add-ons are enabled, native metrics and container logs will not arrive.
5. From `example/`, inspect/merge the Podinfo native scrape job (steps 02/03), preserving unrelated jobs. Check that `container-azm-ms-agentconfig` allows stderr for `demo`. Apply Podinfo (05), keep its port-forward running (06), generate traffic (07), and follow `queries/metrics.promql`, `queries/logs.kql` and `queries/traces.kql`.

There is a small, explicit link between the two configurations: observability reads the existing AKS identity settings; the cluster later consumes its new LAW ID. No `-target`, temporary approval flag or state import is needed. If the LAW is replaced later, review its effect on the AKS input and stored data as well. Do not wire both configurations into mutually dependent simultaneous applies.

The native onboarding templates use the AKS add-ons' managed authentication; they do not add a separate Publisher grant for these native agents. Current Container insights managed-identity authentication explicitly removes that requirement. The Collector's DCR-scoped `Monitoring Metrics Publisher` assignment is separate. [Native Prometheus template](https://raw.githubusercontent.com/Azure/prometheus-collector/main/AddonTerraformTemplate/main.tf) · [Container insights template](https://raw.githubusercontent.com/microsoft/Docker-Provider/ci_prod/scripts/onboarding/aks/onboarding-msi-terraform/main.tf) · [Container insights authentication](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-authentication).

## Collection and investigation boundaries

One Podinfo replica is scraped through its Service by one native job. Do not duplicate it with annotation discovery, PodMonitor/ServiceMonitor or a Collector receiver. Azure Monitor can create its own workspace-managed DCR/DCE; those are not a second Podinfo scrape.

The ContainerInsights DCR collects **only ContainerLogV2**, not the inventory/performance streams needed by every Container insights dashboard. `transform_kql = "source"` preserves the debug request-start events needed for correlation. `namespaceFilteringMode` is not a ContainerLogV2 stdout/stderr namespace filter; shared agent exclusions still apply.

Keep Podinfo private and credential-free: its fault and diagnostic endpoints are not production endpoints. Its plaintext gRPC connection to the Collector is internal. The Collector receiver is unauthenticated; restrict it with enforced NetworkPolicies. Its bounded in-memory queue is lost on restart.

Grafana is single-replica and ephemeral, behind a ClusterIP/loopback port-forward. UI-created dashboards/users can disappear on replacement. Production persistence, availability and access policy are separate decisions. The Grafana admin Secret does not grant Azure access; the federated query identity does.

Microsoft describes [direct Collector OTLP ingestion](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/opentelemetry-options) as generally available; the separate AMA/AKS application-monitoring add-ons are preview. We do not enable those add-ons or register their preview flag. Follow manual orchestration with automatic Application Insights OTLP onboarding **Off**.

Use LAW `OTelSpans` to look up the trace ID from the `ContainerLogV2` request-start event. Application Insights Search/Transaction details can investigate associated native spans where that experience is available. Do not substitute AppRequests/AppTraces. This traces-only Collector does not supply the delta OTLP metrics/exponential histograms needed for the complete Performance/Failures dashboards. Prometheus metrics stay on the native metrics path. No automatic Grafana log-to-trace link is configured.

## Local validation

After adding the provider configuration to this root, from the repository root:

```sh
terraform fmt -check -recursive
terraform -chdir=example/observability init -backend=false -input=false -lockfile=readonly
terraform -chdir=example/observability validate
terraform -chdir=example/observability test
python3 -m unittest discover -s tests -v
```

`terraform validate` checks configuration, not credentials or connectivity. The supplied files alone do not configure deployment access. `terraform test` uses mocked providers; its `command = apply` is not a real deployment. Never substitute ordinary `terraform apply` for this check. Validated locally; Azure deployment, API acceptance, token exchange, webhook mutation, native-agent ingestion, KQL and portal behaviour were not tested.

## Cleanup

Stop port-forwards. Delete only Podinfo's Deployment/Service with step 09 and remove only its added scrape job. To keep the Azure monitoring backends but remove the lab interfaces, remove the two Helm release blocks from the observability configuration and review/apply that change; do not destroy the whole root. Remove an exclusively used Grafana Secret only after its release is gone (step 13). Keep shared namespaces and configuration.

To retire the complete monitoring layer, first remove dependent workloads/Helm, then disable only its dedicated monitoring add-on blocks in the **existing AKS configuration**. After that apply, review removal of the associations and remaining resources in **observability**. Check shared consumers and retention/export requirements: deleting a workspace deletes stored telemetry. Never destroy the AKS configuration or a shared resource group. Keep OIDC/Workload Identity if other workloads use them.

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
