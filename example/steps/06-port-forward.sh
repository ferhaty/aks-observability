kubectl --context "$KUBE_CONTEXT" -n demo port-forward service/podinfo 9898:9898
