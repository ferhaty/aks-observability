# Non-secret rendered configuration also provides an offline integration-test seam.
output "collector_values" { value = yamldecode(helm_release.collector.values[0]) }
output "grafana_values" { value = yamldecode(helm_release.grafana.values[0]) }
