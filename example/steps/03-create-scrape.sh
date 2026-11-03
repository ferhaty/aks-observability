kubectl --context "$KUBE_CONTEXT" -n kube-system create configmap ama-metrics-prometheus-config   --from-file=prometheus-config=native/prometheus-config
