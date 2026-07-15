#!/bin/bash
set -e

echo "==> Criando fila SQS: togglemaster-events"
awslocal sqs create-queue --queue-name togglemaster-events

echo "==> Criando tabela DynamoDB: ToggleMasterAnalytics"
awslocal dynamodb create-table \
    --endpoint-url http://localstack:4566 \
    --table-name ToggleMasterAnalytics \
    --attribute-definitions AttributeName=event_id,AttributeType=S \
    --key-schema AttributeName=event_id,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=1,WriteCapacityUnits=1

echo "==> LocalStack inicializado com sucesso."