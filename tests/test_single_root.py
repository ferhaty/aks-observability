"""Offline architecture and dependency contract; no Azure or Kubernetes calls."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
OBS = ROOT / 'example/observability'

class SingleRoot(unittest.TestCase):
    def test_provider_authentication_is_an_existing_prerequisite(self):
        versions = (OBS/'versions.tf').read_text()
        self.assertIn('required_providers {', versions)
        self.assertNotRegex(versions, r'(?m)^provider\s+"')
        self.assertNotIn('distinct state key', versions)
        for source in [*OBS.glob('*.tf'), OBS/'terraform.tfvars.example',
                       OBS/'tests/contracts.tftest.hcl']:
            text = source.read_text()
            self.assertNotIn('kubeconfig_path', text)
            self.assertNotIn('kubeconfig_context', text)
            self.assertNotIn('kube_admin_config', text)
        variables = (OBS/'variables.tf').read_text()
        self.assertEqual(set(re.findall(r'variable "([^"]+)"', variables)), {
            'name', 'subscription_id', 'tenant_id', 'resource_group_name',
            'aks_name', 'aks_resource_group_name', 'grafana_admin_secret_name'})
        readme = (ROOT/'README.md').read_text()
        self.assertIn('providers.tf', readme)
        self.assertIn('not inherited', readme)
        self.assertIn('existing working kubectl access', readme)

    def test_all_new_resources_are_in_single_root(self):
        body = '\n'.join(p.read_text() for p in OBS.glob('*.tf'))
        for resource in ['azurerm_monitor_workspace', 'azurerm_log_analytics_workspace',
                         'azurerm_application_insights', 'azapi_resource',
                         'azurerm_monitor_data_collection_rule_association',
                         'azurerm_user_assigned_identity', 'azurerm_federated_identity_credential',
                         'azurerm_role_assignment', 'helm_release']:
            self.assertIn('resource "' + resource + '"', body)
        self.assertNotIn('resource "azurerm_kubernetes_cluster"', body)
        self.assertNotIn('azapi_update_resource', body)
        self.assertNotIn('azurerm_dashboard_grafana', body)
        self.assertNotIn('variable "environment"', body)
        self.assertNotIn('terraform_remote_state', body)
        self.assertFalse((ROOT/'example/modules').exists())
        self.assertFalse((ROOT/'example/owner').exists())
        self.assertFalse((ROOT/'example/steps/00-owner-output.sh').exists())

    def test_helm_waits_for_federation_and_scoped_grant(self):
        for filename, identity, role in [('helm.tf', 'traces', 'trace_ingestion'),
                                         ('grafana.tf', 'grafana', 'grafana_metrics')]:
            text = (OBS/filename).read_text()
            deps = re.search(r'depends_on\s*=\s*\[(.*?)\]', text, re.S)
            assert deps is not None, 'Helm authorization ordering missing'
            self.assertIn('azurerm_federated_identity_credential.' + identity, deps[1])
            self.assertIn('azurerm_role_assignment.' + role, deps[1])

    def test_existing_cluster_read_only_prerequisite(self):
        text = (OBS/'existing.tf').read_text()
        self.assertIn('data "azapi_resource" "aks"', text)
        self.assertIn('postcondition', text)
        self.assertIn('self.output.properties.oidcIssuerProfile.enabled == true', text)
        self.assertIn('self.output.properties.securityProfile.workloadIdentity.enabled == true', text)
        self.assertNotIn('kube_config', text)
        self.assertNotIn('depends_on', text)

    def test_aks_settings_only_in_existing_configuration(self):
        snippets = ROOT/'example/aks-settings'
        identity = (snippets/'identity.hcl').read_text()
        monitoring = (snippets/'monitoring.hcl').read_text()
        self.assertRegex(identity, r'oidc_issuer_enabled\s*=\s*true')
        self.assertRegex(identity, r'workload_identity_enabled\s*=\s*true')
        self.assertIn('var.observability_log_analytics_workspace_id', monitoring)
        self.assertRegex(monitoring, r'msi_auth_for_monitoring_enabled\s*=\s*true')
        self.assertIn('monitor_metrics {', monitoring)
        for text in [identity, monitoring]:
            self.assertNotIn('resource "', text)
            self.assertNotIn('module "', text)
        body = '\n'.join(p.read_text() for p in OBS.glob('*.tf'))
        self.assertNotIn('monitor_metrics {', body)
        self.assertNotIn('oms_agent {', body)
        self.assertNotIn('provisioner', body)

if __name__ == '__main__':
    unittest.main()
