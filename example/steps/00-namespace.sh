# Only if observability is absent and its creation is approved. Refuses replacement.
: "${KUBE_CONTEXT:?required}"
kubectl --context "$KUBE_CONTEXT" create namespace observability
