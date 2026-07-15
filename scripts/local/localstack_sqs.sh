#!/bin/bash

watch -n 1 'docker compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localstack:4566/000000000000/togglemaster-events \
  --attribute-names ApproximateNumberOfMessages ApproximateNumberOfMessagesNotVisible'