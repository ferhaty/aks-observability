: "${KUBE_CONTEXT:?required}" "${GRAFANA_ADMIN_USER_FILE:?required}" "${GRAFANA_ADMIN_PASSWORD_FILE:?required}"
kubectl --context "$KUBE_CONTEXT" -n observability create secret generic grafana-admin \
  --from-file=admin-user="$GRAFANA_ADMIN_USER_FILE" \
  --from-file=admin-password="$GRAFANA_ADMIN_PASSWORD_FILE"
