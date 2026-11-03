: "${AKS_ID:?required}" "${KUBE_CONTEXT:?required}"
az aks show --ids "$AKS_ID"   --query '{id:id,identity:identity,metrics:azureMonitorProfile.metrics,logs:addonProfiles.omsagent,oidc:oidcIssuerProfile,workloadIdentity:securityProfile.workloadIdentity}'
az monitor data-collection rule association list-by-resource --resource "$AKS_ID"
kubectl --context "$KUBE_CONTEXT" -n kube-system get pods
