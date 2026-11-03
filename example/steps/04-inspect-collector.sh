kubectl --context "$KUBE_CONTEXT" -n observability rollout status deployment/otel-collector --timeout=180s
kubectl --context "$KUBE_CONTEXT" -n observability logs deployment/otel-collector --tail=100
