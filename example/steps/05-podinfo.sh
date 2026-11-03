kubectl --context "$KUBE_CONTEXT" apply -f podinfo/podinfo.yaml
kubectl --context "$KUBE_CONTEXT" -n demo rollout status deployment/podinfo --timeout=180s
kubectl --context "$KUBE_CONTEXT" -n demo get pods -l app=podinfo
