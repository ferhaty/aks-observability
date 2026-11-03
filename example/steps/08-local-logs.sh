kubectl --context "$KUBE_CONTEXT" -n demo logs deployment/podinfo --tail=100
