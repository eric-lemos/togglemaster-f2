#!/bin/bash

bash "scripts/aws/reset_sqs_queue.sh" && clear
NLB_ENDPOINT="" # Insert the AWS ingress URL here
SERVICE_API_KEY="" # Insert the valid service API key here
EVALUATION_PATH="evaluation-service/evaluate?flag_name=my-flag&user_id=my-user"

hey -n 10000 -c 100 \
    -H "Authorization: Bearer $SERVICE_API_KEY" \
    "$NLB_ENDPOINT/$EVALUATION_PATH"