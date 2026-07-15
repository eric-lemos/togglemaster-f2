#!/bin/bash
clear

# Global variables
API_KEY=${1:-""}
HOSTNAME=${2:-${HOSTNAME:-localhost}}

# Color formatting for output
declare -A FMT=(
    [red]='\e[1;31m'
    [green]='\e[1;32m'
    [yellow]='\e[1;33m'
    [blue]="\e[0;36m"
    [bold]='\e[1;37m'
    [nc]='\e[0m'
)

# Function to check the health of services running on ports 8001 to 8005
healthCheck() {
    local RESPONSE
    local COUNT_UNHEALTHY=0; sleep 1
    for PORT in {8001..8005}; do
        RESPONSE=$(curl -s -X GET "http://$HOSTNAME:$PORT/health");
        if [[ "$RESPONSE" ]]; then
            echo -e "[${FMT[green]}OK${FMT[nc]}] Service on port $PORT is healthy."
        else
            echo -e "[${FMT[red]}ERROR${FMT[nc]}] Service on port $PORT is not healthy."
            COUNT_UNHEALTHY=$((COUNT_UNHEALTHY + 1))
        fi; sleep 0.25
    done

    if [[ $COUNT_UNHEALTHY -ne 0 ]]; then
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] $COUNT_UNHEALTHY services are not healthy. Exiting with status code 1."
        exit 1
    else
        echo -e "[${FMT[green]}OK${FMT[nc]}] All services are healthy."; sleep 0.25
        echo -e "\n${FMT[blue]}>> docker container ls${FMT[nc]}"; sleep 0.25
        docker ps --format "table {{.Names}}\t{{.Status}}"
    fi
}

# Function to create an API key for testing
createApiKey() {
    local RESPONSE
    local MASTER_KEY=${1:-"local-master-key"}; sleep 1
    if [ -n "$API_KEY" ]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] API key already exists."
    else
        RESPONSE=$(
            curl -s -X POST "http://$HOSTNAME:8001/admin/keys" \
            -H "Authorization: Bearer $MASTER_KEY" \
            -H "Content-Type: application/json" \
            -d '{"name": "my-api-key"}'
        ); sleep 0.25

        if [[ "$(echo "$RESPONSE" | jq -r '.key')" != "" ]]; then
            echo -e "[${FMT[green]}OK${FMT[nc]}] API key created successfully."
            API_KEY=$(echo "$RESPONSE" | jq -r '.key')
            echo "$RESPONSE" | jq .
        else
            echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to create API key."
            echo "$RESPONSE" | jq .
            exit 1
        fi
    fi
}

# Function to validate the API key
validateApiKey() {
    local RESPONSE; sleep 1
    local API_KEY_HASH=${1:-"$API_KEY"}
    RESPONSE=$(
        curl -s -X GET "http://$HOSTNAME:8001/validate" \
        -H "Authorization: Bearer $API_KEY_HASH"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.message')" == "Chave válida" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] API key is valid."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] API key is not valid."
        # echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to list flags, optionally filtering by name
listFlags() {
    local RESPONSE; sleep 1
    local FILTER_BY_NAME=${1:-""}
    local API_KEY_HASH=${2:-$API_KEY}
    RESPONSE=$(
        curl -s -X GET "http://$HOSTNAME:8002/flags" \
        -H "Authorization: Bearer $API_KEY_HASH"
    ); sleep 0.25

    if [[ "$RESPONSE" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Flags retrieved successfully."
        if [[ "$(echo "$RESPONSE" | jq 'length')" -eq 0 ]]; then
            echo -e "${FMT[red]}No flags found.${FMT[nc]}"
            echo "$RESPONSE" | jq .
        elif [ -n "$FILTER_BY_NAME" ]; then
            echo "$RESPONSE" | jq ".[] | select(.name==\"$FILTER_BY_NAME\")"
        else 
            echo "$RESPONSE" | jq 'sort_by(.id) | .[-3:]'
        fi
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to retrieve flags."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to generate a unique flag name
genFlagName() {
    local FLAG_HASH FLAG_NAME=${1:-"flag"}
    FLAG_HASH=$(echo -n "${FLAG_NAME}-$(date +%s%N)-$RANDOM" | sha256sum | cut -c1-6)
    echo "${FLAG_NAME}-${FLAG_HASH}"
}

# Function to create a new flag
createFlag() {
    local RESPONSE
    local FLAG_NAME=$1
    local FLAG_STATUS=$2
    local API_KEY_HASH=${3:-$API_KEY}; sleep 1
    RESPONSE=$(
        curl -s -X POST "http://$HOSTNAME:8002/flags" \
        -H "Authorization: Bearer $API_KEY_HASH" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$FLAG_NAME\", \"is_enabled\": $FLAG_STATUS}"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.name')" == "$FLAG_NAME" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Flag created successfully."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to create flag."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to update the status of an existing flag
updateFlag() {
    local RESPONSE
    local FLAG_NAME=$1
    local FLAG_STATUS=$2
    local API_KEY_HASH=${3:-$API_KEY}; sleep 1
    RESPONSE=$(
        curl -s -X PUT "http://$HOSTNAME:8002/flags/$FLAG_NAME" \
        -H "Authorization: Bearer $API_KEY_HASH" \
        -H "Content-Type: application/json" \
        -d "{\"is_enabled\": $FLAG_STATUS}"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.name')" == "$FLAG_NAME" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Flag updated successfully."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to update flag."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to create a new rule for a flag
createRule() {
    local RESPONSE
    local FLAG_NAME=$1
    local RULE_TYPE=$2
    local RULE_VALUE=$3
    local API_KEY_HASH=${4:-$API_KEY}; sleep 1
    RESPONSE=$(
        curl -s -X POST "http://$HOSTNAME:8003/rules" \
        -H "Authorization: Bearer $API_KEY_HASH" \
        -H "Content-Type: application/json" \
        -d "{
                \"flag_name\": \"$FLAG_NAME\",
                \"is_enabled\": true,
                \"rules\": {
                    \"type\": \"$RULE_TYPE\",
                    \"value\": $RULE_VALUE
                }
            }"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.flag_name')" == "$FLAG_NAME" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Rule created successfully."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to create rule."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to search for a rule by flag name
searchRule() {
    local RESPONSE
    local FLAG_NAME=$1
    local API_KEY_HASH=${2:-$API_KEY}; sleep 1
    RESPONSE=$(curl -s -X GET "http://$HOSTNAME:8003/rules/$FLAG_NAME" \
        -H "Authorization: Bearer $API_KEY_HASH"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.flag_name')" == "$FLAG_NAME" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Rule found successfully."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Rule not found."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to update an existing rule for a flag
updateRule() {
    local RESPONSE
    local FLAG_NAME=$1
    local RULE_TYPE=$2
    local RULE_VALUE=$3
    local API_KEY_HASH=${4:-$API_KEY}; sleep 1
    RESPONSE=$(
        curl -s -X PUT "http://$HOSTNAME:8003/rules/$FLAG_NAME" \
        -H "Authorization: Bearer $API_KEY_HASH" \
        -H "Content-Type: application/json" \
        -d "{
                \"rules\": {
                    \"type\": \"$RULE_TYPE\",
                    \"value\": $RULE_VALUE
                }
            }"
    ); sleep 0.25

    if [[ "$(echo "$RESPONSE" | jq -r '.flag_name')" == "$FLAG_NAME" ]]; then
        echo -e "[${FMT[green]}OK${FMT[nc]}] Rule updated successfully."
        echo "$RESPONSE" | jq .
    else
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to update rule."
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Function to generate a unique user ID
genUserId() {
    local USER_HASH USER_NAME=${1:-"user"}
    USER_HASH=$(echo -n "${USER_NAME}-$(date +%s%N)-$RANDOM" | sha256sum | cut -c1-6)
    echo "${USER_NAME}-${USER_HASH}"
}

# Function to configure the evaluation service container with the correct API key
configEvaluation() {
    local CURRENT_API_KEY
    local NEW_SERVICE_API_KEY=${1:-"$API_KEY"}
    export SERVICE_API_KEY="$NEW_SERVICE_API_KEY"; sleep 1
    docker compose up -d --no-deps --force-recreate evaluation-service > /dev/null 2>&1
    CURRENT_API_KEY=$(docker compose exec evaluation-service printenv SERVICE_API_KEY)
    if [[ "$CURRENT_API_KEY" != "$NEW_SERVICE_API_KEY" ]]; then
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to set SERVICE_API_KEY in evaluation-service container."
        exit 1
    fi
    echo -e "[${FMT[green]}OK${FMT[nc]}] SERVICE_API_KEY set successfully in evaluation-service container."
    echo -e "\n${FMT[blue]}>> docker compose exec evaluation-service printenv SERVICE_API_KEY${FMT[nc]}"; sleep 0.25
    echo "$CURRENT_API_KEY"
}

# Function to evaluate a flag for a specific user or multiple users (and count the results)
evaluationTests() {
    local FLAG_NAME=$1
    local NUM_TESTS=${2:-3}
    local FIXED_USER_ID=${3:-""}
    local RESPONSE CONT_TRUE=0 CONT_FALSE=0 CURRENT_USER; sleep 1

    for NUM_TEST in $(seq 1 "$NUM_TESTS"); do
        if [[ -n "$FIXED_USER_ID" ]]; then
            CURRENT_USER="$FIXED_USER_ID"
        else
            CURRENT_USER=$(genUserId)
        fi

        echo -e "${FMT[bold]}#$NUM_TEST${FMT[nc]} Evaluating '$FLAG_NAME' for user '$CURRENT_USER'..."; sleep 0.25
        RESPONSE=$(curl -s -X GET "http://$HOSTNAME:8004/evaluate?user_id=$CURRENT_USER&flag_name=$FLAG_NAME")

        if [[ "$(echo "$RESPONSE" | jq -r '.flag_name')" == "$FLAG_NAME" ]]; then
            echo -e "[${FMT[green]}OK${FMT[nc]}] Evaluation #$NUM_TEST successful."
            if [[ "$(echo "$RESPONSE" | jq -r '.result')" == "true" ]]; then
                CONT_TRUE=$((CONT_TRUE + 1))
            else
                CONT_FALSE=$((CONT_FALSE + 1))
            fi
            echo "$RESPONSE" | jq .
        else
            echo -e "[${FMT[red]}ERROR${FMT[nc]}] Evaluation #$NUM_TEST failed."
            echo "$RESPONSE" | jq .
            exit 1
        fi
        echo && sleep 1
    done

    echo -e "Results:\n[${FMT[green]}True=${CONT_TRUE}${FMT[nc]}] [${FMT[red]}False=${CONT_FALSE}${FMT[nc]}]"
    echo -e "\n${FMT[blue]}>> docker logs tm-evaluation-service | grep -E \"Cache (MISS|HIT) para flag '$FLAG_NAME'\"${FMT[nc]}"; sleep 0.25
    docker logs tm-evaluation-service | grep -E "Cache (MISS|HIT) para flag '$FLAG_NAME'"
}

analyticsLogs() {
    echo -e "\n${FMT[blue]}>> docker logs tm-analytics-service --tail 15${FMT[nc]}"; sleep 0.25
    docker logs tm-analytics-service --tail 15
}

main() {
    local GENERATED_FLAG_NAME
    GENERATED_FLAG_NAME=$(genFlagName)
    
    echo -e "*** ${FMT[bold]}Tests to validate the deployment of the ToggleMaster${FMT[nc]} ***"; sleep 0.25
    echo -e "${FMT[bold]}Endpoint:${FMT[nc]} ${FMT[blue]}$HOSTNAME${FMT[nc]}"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Starting health checks for services on ports 8001 to 8005...${FMT[nc]}\n"; healthCheck
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Creating an API key for testing...${FMT[nc]}\n"; createApiKey
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Validating the created API key...${FMT[nc]}\n"; validateApiKey
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Listing the latest flags created...${FMT[nc]}\n"; listFlags
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Creating a new flag...${FMT[nc]}\n"; createFlag "$GENERATED_FLAG_NAME" "false"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Updating the flag status...${FMT[nc]}\n"; updateFlag "$GENERATED_FLAG_NAME" "true"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Listing again the last flags created...${FMT[nc]}\n"; listFlags
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Creating a new rule for the flag...${FMT[nc]}\n"; createRule "$GENERATED_FLAG_NAME" "PERCENTAGE" 75
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Searching for the created rule...${FMT[nc]}\n"; searchRule "$GENERATED_FLAG_NAME"
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Updating the rule for the flag...${FMT[nc]}\n"; updateRule "$GENERATED_FLAG_NAME" "PERCENTAGE" 50
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Configuring service API key for evaluation service container...${FMT[nc]}\n"; configEvaluation
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Evaluating the flag for multiple users...${FMT[nc]}\n"; evaluationTests "$GENERATED_FLAG_NAME" 5
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Fetching analytics logs...${FMT[nc]}\n"; analyticsLogs
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[bold]} All tests completed successfully!${FMT[nc]}\n"
}

main