kubectl --context "$KUBE_CONTEXT" -n observability get serviceaccount grafana -o yaml
kubectl --context "$KUBE_CONTEXT" -n observability get pods -l app.kubernetes.io/instance=grafana -o yaml
kubectl --context "$KUBE_CONTEXT" -n observability logs deployment/grafana --tail=100
