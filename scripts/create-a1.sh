#!/usr/bin/env bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "ERROR: .env file not found."
    exit 1
fi

source "$PROJECT_ROOT/.env"

LOG_DIR="$PROJECT_ROOT/logs"
LOG_FILE="$LOG_DIR/creator.log"

mkdir -p "$LOG_DIR"

log() {
    local message="$1"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

    echo "[$timestamp] $message"
    echo "[$timestamp] $message" >> "$LOG_FILE"
}

send_telegram() {
    "$PROJECT_ROOT/scripts/telegram.sh" "$1"
}

INSTANCE_NAME="oracle-a1"

echo "=========================================="
echo " Oracle A1 Creator"
echo "=========================================="

echo "Region:              $OCI_REGION"
echo "Availability Domain: $OCI_AVAILABILITY_DOMAIN"
echo "Shape:               VM.Standard.A1.Flex"
echo "OCPU:                2"
echo "Memory:              12 GB"
echo

log "Checking if instance already exists..."

INSTANCE_COUNT=$(oci compute instance list \
    --compartment-id "$OCI_COMPARTMENT_ID" \
    --display-name "$INSTANCE_NAME" \
    --query 'length(data)' \
    --raw-output)

if [[ "$INSTANCE_COUNT" -gt 0 ]]; then
    log "Instance '$INSTANCE_NAME' already exists."
    log "Nothing to do."
    echo "" >> "$LOG_FILE"
    exit 0
fi

log "Instance '$INSTANCE_NAME' does not exist."

log "Attempting to create instance..."

echo "" >> "$LOG_FILE"


OUTPUT=$(oci compute instance launch \
    --compartment-id "$OCI_COMPARTMENT_ID" \
    --availability-domain "$OCI_AVAILABILITY_DOMAIN" \
    --shape "VM.Standard.A1.Flex" \
    --shape-config '{"ocpus":2,"memoryInGBs":12}' \
    --image-id "$OCI_IMAGE_ID" \
    --subnet-id "$OCI_SUBNET_ID" \
    --assign-public-ip true \
    --display-name "$INSTANCE_NAME" 2>&1)

EXIT_CODE=$?

if [[ $EXIT_CODE -eq 0 ]]; then
    log "SUCCESS: Instance created."
    echo "$OUTPUT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"

    send_telegram "🎉 Oracle A1 Creator: ¡INSTANCIA CREADA!

Instance: $INSTANCE_NAME
Shape: VM.Standard.A1.Flex
OCPU: 2
Memory: 12 GB
Region: $OCI_REGION
Availability Domain: $OCI_AVAILABILITY_DOMAIN"

    exit 0
fi

if echo "$OUTPUT" | grep -q "Out of host capacity\|Out of capacity"; then
    log "CAPACITY: No host capacity available."
    echo "$OUTPUT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    exit 0
fi

if echo "$OUTPUT" | grep -q "TooManyRequests\|Too many requests"; then
    log "RATE_LIMIT: Oracle rate limit reached."
    echo "$OUTPUT" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    exit 0
fi

log "UNEXPECTED_ERROR: OCI returned an unexpected error."
echo "$OUTPUT" >> "$LOG_FILE"

send_telegram "🚨 Oracle A1 Creator: ERROR INESPERADO

OCI ha devuelto un error que el script no reconoce.

$OUTPUT"

exit 1