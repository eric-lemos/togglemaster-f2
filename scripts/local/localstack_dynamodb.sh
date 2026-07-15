#!/bin/bash

# Color formatting for output
declare -A FMT=(
    [red]='\e[1;31m'
    [green]='\e[1;32m'
    [yellow]='\e[1;33m'
    [blue]="\e[0;36m"
    [bold]='\e[1;37m'
    [nc]='\e[0m'
)

# List all DynamoDB tables in the LocalStack environment
echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
echo -e "${FMT[yellow]}>> Listing all DynamoDB tables in LocalStack...\n${FMT[nc]}"
docker compose exec -T localstack awslocal dynamodb list-tables

# Scan the "ToggleMasterAnalytics" table in the LocalStack DynamoDB environment
echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
echo -e "${FMT[yellow]}Scanning the 'ToggleMasterAnalytics' table in LocalStack...\n${FMT[nc]}"
docker compose exec -T localstack awslocal dynamodb scan --table-name "ToggleMasterAnalytics" --output json