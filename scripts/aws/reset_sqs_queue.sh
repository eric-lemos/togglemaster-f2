#!/bin/bash
set -e

declare -A FMT=(
    [red]='\e[1;31m'
    [green]='\e[1;32m'
    [yellow]='\e[1;33m'
    [blue]="\e[0;36m"
    [bold]='\e[1;37m'
    [nc]='\e[0m'
)

AWS_REGION="us-east-1"
AWS_SQS_URL="" # Insert your SQS queue URL here

clear_sqs_queue() {
    local queue_url="$1"
    local region="$2"

    aws sqs purge-queue \
        --queue-url "$queue_url" \
        --region "$region"
    echo -e "[${FMT[green]}OK${FMT[nc]}] SQS queue purge requested successfully."
}

clear_sqs_queue "$AWS_SQS_URL" "$AWS_REGION"