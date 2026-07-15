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
AWS_DYNAMODB_TABLE="" # Insert your DynamoDB table name here

clear_sqs_queue() {
    local queue_url="$1"
    local region="$2"

    aws sqs purge-queue \
        --queue-url "$queue_url" \
        --region "$region"
    echo -e "[${FMT[green]}OK${FMT[nc]}] SQS queue purge requested successfully."
}

clear_dynamodb_table() {
    local table_name="$1"
    local region="$2"

    echo -e "[${FMT[blue]}INFO${FMT[nc]}] Reading items from DynamoDB table..."
    local event_ids

    event_ids=$(aws dynamodb scan \
        --table-name "$table_name" \
        --region "$region" \
        --projection-expression "event_id" \
        --query "Items[].event_id.S" \
        --output text)

    if [[ -z "$event_ids" || "$event_ids" == "None" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] DynamoDB table was already empty."
        return
    fi

    local deleted_count=0
    for event_id in $event_ids; do
        aws dynamodb delete-item \
            --table-name "$table_name" \
            --region "$region" \
            --key "{\"event_id\":{\"S\":\"$event_id\"}}" >/dev/null
        deleted_count=$((deleted_count + 1))
    done

    echo -e "[${FMT[green]}OK${FMT[nc]}] DynamoDB items deleted: $deleted_count"
}

main() {
    clear
    echo -e "${FMT[bold]}*** Reset SQS queue and DynamoDB table ***${FMT[nc]}"; sleep 0.25
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Clearing SQS queue...${FMT[nc]}\n"; clear_sqs_queue "$AWS_SQS_URL" "$AWS_REGION"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Clearing DynamoDB table...${FMT[nc]}\n"; clear_dynamodb_table "$AWS_DYNAMODB_TABLE" "$AWS_REGION"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "\n${FMT[bold]}SQS queue and DynamoDB table cleared successfully.${FMT[nc]}\n"
}

main