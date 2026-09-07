#!/usr/bin/env bash

set -u

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "ERROR: .env file not found."
    exit 1
fi

source "$PROJECT_ROOT/.env"

: "${TELEGRAM_BOT_TOKEN:?TELEGRAM_BOT_TOKEN is not set}"
: "${TELEGRAM_CHAT_ID:?TELEGRAM_CHAT_ID is not set}"

if [[ $# -eq 0 ]]; then
    echo "ERROR: No message provided."
    exit 1
fi

MESSAGE="$1"

curl -sS \
    --fail \
    --request POST \
    "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
    --data-urlencode "text=${MESSAGE}" \
    > /dev/null

echo "Telegram notification sent."