# AKS observability examples

Companion configuration for **Observability on Azure AKS: Metrics, Logs and Traces** by Ferhat Yildiz / Turing Technology Services. Visit the [Turing blog](https://blog.turingts.com/).

The example investigates a failed request to [Podinfo](https://github.com/stefanprodan/podinfo/tree/6.9.2), using three separate telemetry paths:

- **Metrics:** AKS `ama-metrics` → Azure Monitor managed Prometheus → self-hosted Grafana Community Edition (OSS).
- **Logs:** Container insights / `ama-logs` → its Data Collection Rule (DCR) → `ContainerLogV2` in Log Analytics.
- **Traces:** Podinfo OTLP/gRPC → a traces-only OpenTelemetry Collector → Azure Monitor native OTLP HTTP/protobuf → `OTelSpans`.

Grafana has its own Workload Identity with **Monitoring Data Reader** on the Azure Monitor workspace. The Collector has a different identity with **Monitoring Metrics Publisher** on the trace DCR. Neither uses the pipeline's deployment credentials.

## Scope and prerequisites

This is an addition to an **existing AKS cluster and deployment pipeline**, not a cluster bootstrap module or an automatic cloud deployment. There are no GitHub Actions workflows.

Before using the deployment files, the resource owners must supply and approve:

- A managed-identity AKS cluster with Linux amd64 capacity, OIDC issuer and Microsoft Entra Workload ID enabled; authorized Kubernetes access and an existing Terraform backend/authentication process.
- Native metrics onboarding to the chosen **Azure Monitor workspace**, including its DCR/DCE, AKS association, ingestion identity and Prometheus **query endpoint**.
- Container insights onboarding to the chosen **Log Analytics workspace**, including its DCR/association and agent configuration that retains Podinfo debug request-start events.
- An **OTLP-enabled Application Insights setup** and its exact trace DCR resource ID, full per-signal ingestion URL and destination Log Analytics workspace. This may be a different workspace from Container insights.
- Approval for the `observability` tooling namespace and an isolated `demo` namespace. Namespace separation is not a NetworkPolicy boundary.
- Subscription/tenant, identity resource group/location, exact OIDC issuer URL, and an authorized kubeconfig path/context. Preserve an issuer's trailing slash.
- An owner-managed `grafana-admin` Secret in `observability`, with `admin-user` and `admin-password` keys, before installing Grafana.
- Pipeline permission to create the supplementary identities, federations and scoped role assignments, plus separate Kubernetes authorization for Helm. The owners retain cluster, workspace, DCR and provider-registration responsibilities.

**Native OTLP ingestion is a preview design choice.** Confirm the intended region, available onboarding and preview acceptance with the backend owner before deployment. The Collector components are community-supported; local configuration checks do not prove Azure support. This example does not enable AKS auto-instrumentation as a second trace path. An Application Insights connection string is not a substitute for the full OTLP endpoint and Entra authentication.

Workloads need their existing DNS/routing and access to image registries, Azure ingestion/query endpoints and Entra. Grafana downloads its pinned Azure Prometheus plugin at startup; restricted networks need an approved package mirror or preinstalled image. This repository does not establish Private Link connectivity.

## Files

| Path | Purpose |
| --- | --- |
| `example/observability/` | Supplementary Terraform root: separate identities, RBAC, Collector and Grafana Helm releases, and values templates. Includes the pinned provider lock. |
| `example/observability/terraform.tfvars.example` | Placeholder inputs only; replace every value through the existing pipeline's input mechanism. |
| `example/observability/tests/` | Terraform mock-provider contracts and rejected-endpoint controls; no Azure calls. |
| `example/owner/*.tf.fragment` | Fragments for the **existing owner's state**, not standalone onboarding or a second cluster resource. |
| `example/native/prometheus-config` | One replica-level native-agent scrape job for the single Podinfo replica. |
| `example/podinfo/podinfo.yaml` | Pinned upstream demo image, Deployment, ClusterIP Service and `demo` namespace. |
| `example/steps/` | Article command snippets; inspect and run only the relevant step, not every file in numerical order. |
| `example/queries/` | PromQL and KQL for the manual metrics → log → trace investigation. |

The owner fragments deliberately do **not** create a cluster, metrics destination, complete ContainerInsights rule, or native OTLP backend. Merge them into the existing resource definitions without importing a cluster into two states or replacing unrelated streams/destinations. Keep the owner's existing backend configuration for the supplementary root; do not accidentally deploy using local state.

## Version pins

| Component | Version |
| --- | --- |
| Terraform requirement | `>= 1.10.0, < 2.0.0` |
| AzureRM provider | `5.12.0` |
| Helm provider | `3.3.0` |
| OpenTelemetry Collector chart / contrib image | `0.176.1` / `0.162.0` |
| Grafana community chart / OSS image | `14.0.1` / `13.2.4-distroless` |
| Grafana Azure Prometheus plugin | `1.0.10` |
| Podinfo | `6.9.2`, image digest pinned in the manifest |

These are the example's tested pins, not a request to upgrade an existing cluster or a claim that they are the latest versions. The lock was checked on Linux amd64; generate/check the required provider checksums when using another workstation platform.

## Start with local checks

Clone the repository, then validate without configuring Azure credentials:

```sh
git clone https://github.com/ferhaty/aks-observability.git
cd aks-observability
terraform -chdir=example/observability fmt -check -recursive
terraform -chdir=example/observability init -backend=false -input=false -lockfile=readonly
terraform -chdir=example/observability validate
terraform -chdir=example/observability test
for file in example/steps/*.sh; do bash -n "$file" || break; done
```

`init` downloads providers; the test file mocks **both** providers. Its `command = apply` applies the mocked graph, not Azure resources or Helm releases. Do not substitute an ordinary `terraform apply` for `terraform test`. Do not run a real plan/apply until the owners have supplied the approved resources, backend, credentials and access through their established process.

The source was locally checked with Terraform validation/mock tests, Helm rendering/linting, Kubernetes JSON schemas and Collector configuration validation. **It has not been deployed to Azure.** These checks do not verify Azure permissions, token exchange, the Workload ID webhook, managed-agent ingestion, KQL execution or end-to-end delivery.

## Deployment sequence for an approved existing environment

Run file-based kubectl commands from `example/`, their common parent. Set `KUBE_CONTEXT` explicitly and inspect that context before each mutating step; the snippets do not select or create a cluster for you.

1. Have the existing owners complete native onboarding and verify the destination DCR associations. `steps/01-inspect.sh` contains read-only inspection commands and also requires `AKS_ID`.
2. Inspect the existing `ama-metrics-prometheus-config` ConfigMap with `steps/02-inspect-scrape.sh`. **If it exists, merge the Podinfo job through its owner; do not replace the other jobs.** Use `steps/03-create-scrape.sh` only when it does not exist and creation is approved. Do not also scrape Podinfo through annotations, a PodMonitor/ServiceMonitor or a Collector Prometheus receiver.
3. Have the namespace owner create `observability`. If the Grafana Secret does not already exist, `steps/10-grafana-secret.sh` reads its two values from local owner-managed files named by `GRAFANA_ADMIN_USER_FILE` and `GRAFANA_ADMIN_PASSWORD_FILE`. Do not commit these files or their contents. Use the owner's secret-management process for existing Secrets.
4. Supply the placeholder inputs and install the supplementary Terraform root through the existing approved pipeline. `steps/04-inspect-collector.sh` checks the Collector; `steps/11-grafana-access.sh` checks Grafana and starts a loopback port-forward to `http://localhost:3000`. Keep that terminal open; `steps/12-grafana-inspect.sh` provides diagnostic reads.
5. After confirming ownership of `demo`, deploy Podinfo using `steps/05-podinfo.sh`. In another terminal run `steps/06-port-forward.sh`, then use `steps/07-traffic.sh` to generate bounded success/error traffic. The intentional `/status/500` response is the exercise, not an unexpected test failure.
6. Run each expression in `queries/metrics.promql` separately in Grafana. Find the request-start event with `queries/logs.kql` in the **container-log workspace**; copy its trace ID into `queries/traces.kql` in the **trace workspace**. `steps/08-local-logs.sh` helps distinguish missing source logs from ingestion problems. Log events describe request start, not the final response status; inspect the server span for the outcome.

Grafana uses ephemeral storage in this small example: local UI changes can disappear on Pod replacement. Its admin login is not an Azure credential. Production persistence, access controls, availability and network policy remain owner decisions.

**Keep Podinfo private and free of credentials.** It exposes diagnostic/configuration and fault endpoints. Do not inject Azure credentials, API keys or real application secrets into this demo, and do not expose it through a public ingress. The supplied ClusterIP plus loopback port-forward is the intended access path.

## Cleanup

Stop the local port-forwards. `steps/09-cleanup.sh` removes only the named Podinfo Deployment and Service, not the namespace or Azure monitoring backends. Remove the exact added scrape job through its owner without deleting a shared ConfigMap. Remove Collector/Grafana and their supplementary identity/RBAC resources only through the same owning Terraform state, after reviewing that plan. `steps/13-grafana-secret-cleanup.sh` is optional: run it only if this exercise created that Secret and nothing else uses it. Never destroy shared workspaces, DCRs or the existing cluster as demo cleanup.

## Upstream software and licensing

Podinfo is the upstream project by Stefan Prodan and contributors, not an application implemented by this repository. [Podinfo 6.9.2's licence](https://github.com/stefanprodan/podinfo/blob/6.9.2/LICENSE) is Apache-2.0 and retains `Copyright 2018 Stefan Prodan. All rights reserved.` This repository references its released container image; it does not vendor the application source or binary. Helm charts, Collector, Grafana and plugins remain separate upstream software with their own licences and notices.

No blanket licence has been selected for this repository's own example files. The upstream Podinfo licence does not automatically license these configuration examples.

## References

- [Azure Kubernetes monitoring onboarding](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/kubernetes-monitoring-enable)
- [Azure Monitor native OTLP ingestion](https://learn.microsoft.com/en-us/azure/azure-monitor/containers/opentelemetry-protocol-ingestion)
- [Grafana authentication for Azure managed Prometheus](https://learn.microsoft.com/en-us/azure/azure-monitor/metrics/prometheus-grafana)
- [OpenTelemetry Helm charts](https://github.com/open-telemetry/opentelemetry-helm-charts)
- [Grafana community Helm charts](https://github.com/grafana-community/helm-charts)
