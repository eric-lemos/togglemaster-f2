#!/bin/bash
clear

# Color formatting for output
declare -A FMT=(
    [red]='\e[1;31m'
    [green]='\e[1;32m'
    [yellow]='\e[1;33m'
    [blue]="\e[0;36m"
    [bold]='\e[1;37m'
    [nc]='\e[0m'
)

# Global variables
VERSION="2.0.0"
REGION="us-east-1"
NAMESPACE="togglemaster"
ACCOUNT_ID="" # Insert your AWS account ID here
ECR_URL="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$NAMESPACE"
APPS=("auth-service" "flag-service" "targeting-service" "evaluation-service" "analytics-service")
APPS_PATH="" # Insert the path to your applications directory here

login() {
    local LOGIN_RESPONSE
    LOGIN_RESPONSE=$(aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL)

    if [ "$LOGIN_RESPONSE" != "Login Succeeded" ]; then
        echo -e "[${FMT[red]}ERROR${FMT[nc]}] Failed to log in to AWS ECR."
        exit 1
    fi
    echo -e "[${FMT[green]}OK${FMT[nc]}] Logged in to AWS ECR successfully."; sleep 0.25
}

build() {
    for APP in "${APPS[@]}"; do
        echo -e "${FMT[blue]}>> docker build -t \"$APP\" \"$APPS_PATH/$APP\"${FMT[nc]}"
        docker build -t "$APP" "$APPS_PATH/$APP"
        echo && sleep 0.25
    done
    echo -e "[${FMT[green]}OK${FMT[nc]}] All Docker images built successfully."; sleep 0.25
}

push() {
    for APP in "${APPS[@]}"; do
        echo -e "${FMT[blue]}>> docker tag \"$APP\" \"$ECR_URL/$APP:latest\"${FMT[nc]}"
        docker tag "$APP" "$ECR_URL/$APP:$VERSION"
        docker tag "$APP" "$ECR_URL/$APP:latest"
        echo -e "${FMT[blue]}>> docker push \"$ECR_URL/$APP:latest\"${FMT[nc]}"
        docker push "$ECR_URL/$APP:$VERSION"
        docker push "$ECR_URL/$APP:latest"
        echo && sleep 0.25
    done
    echo -e "[${FMT[green]}OK${FMT[nc]}] All Docker images pushed to AWS ECR successfully."; sleep 0.25
}

main() {
    echo -e "*** ${FMT[bold]}Starting to send Docker images to ECR${FMT[nc]} ***"; sleep 0.25
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Logging in to AWS ECR...${FMT[nc]}\n"; login
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Building Docker images...${FMT[nc]}\n"; build
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Pushing Docker images to ECR...${FMT[nc]}"; push
}

main