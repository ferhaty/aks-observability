kubectl --context "$KUBE_CONTEXT" -n observability rollout status deployment/grafana --timeout=180s
kubectl --context "$KUBE_CONTEXT" -n observability port-forward service/grafana 3000:80
