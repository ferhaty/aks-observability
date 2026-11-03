# After the approved owner-root apply; exports explicit non-secret output only.
set -euo pipefail
: "${OWNER_ROOT:?existing AKS Terraform root required}" "${EXAMPLE_ROOT:?absolute path to example required}"
umask 077
input_file=$(mktemp "$EXAMPLE_ROOT/observability/.owner-inputs.XXXXXX")
trap 'rm -f "$input_file"' EXIT
terraform -chdir="$OWNER_ROOT" output -json observability_inputs > "$input_file"
mv "$input_file" "$EXAMPLE_ROOT/observability/owner.auto.tfvars.json"
terraform -chdir="$OWNER_ROOT" output -json monitoring_inspection
