"""Offline structural contract; provider mocks separately test evaluated outputs."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SourceContract(unittest.TestCase):
    def test_backend_and_owner_are_complete_without_second_cluster_state(self):
        module = ROOT / 'example/modules/azure-monitor'
        self.assertTrue((module / 'backends.tf').is_file(), 'Missing provisioned monitoring backends')
        body = '\n'.join(p.read_text() for p in module.glob('*.tf'))
        for resource in ['azurerm_monitor_workspace', 'azurerm_log_analytics_workspace',
                         'azurerm_application_insights', 'azapi_resource',
                         'azurerm_monitor_data_collection_rule_association']:
            self.assertIn('resource "' + resource + '"', body)
        self.assertNotIn('resource "azurerm_kubernetes_cluster"', body)
        self.assertNotIn('azurerm_dashboard_grafana', body)
        self.assertNotIn('azapi_update_resource', body)
        self.assertRegex(body, r'replaceResourceIdWithReference\s*=\s*true')
        self.assertIn('directDataSources', body)
        self.assertNotIn('otelMetrics =', body)
        self.assertNotIn('otelLogs =', body)
        owner = (ROOT / 'example/owner/monitoring.tf.example').read_text()
        self.assertIn('module "monitoring"', owner)
        self.assertIn('azurerm_kubernetes_cluster.aks.oidc_issuer_url', owner)
        self.assertIn('output "observability_inputs"', owner)
        self.assertFalse(list((ROOT / 'example/owner').glob('*.fragment')))

if __name__ == '__main__':
    unittest.main()
