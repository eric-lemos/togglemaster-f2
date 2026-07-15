#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
declare -A FMT=(
    [red]='\e[1;31m'
    [green]='\e[1;32m'
    [yellow]='\e[1;33m'
    [blue]="\e[0;36m"
    [bold]='\e[1;37m'
    [nc]='\e[0m'
)

NAMESPACE="togglemaster"
JOB_NAME="postgres-schema-init"
CONFIGMAP_NAME="postgres-schema-sql"
MANIFEST_PATH="$ROOT_DIR/k8s/jobs/postgres-job.yaml"

check_job() {
    if kubectl -n "$NAMESPACE" get job "$JOB_NAME" &> /dev/null; then
        kubectl -n "$NAMESPACE" delete job "$JOB_NAME" --ignore-not-found=true
        kubectl -n "$NAMESPACE" delete configmap "$CONFIGMAP_NAME" --ignore-not-found=true
        echo -e "[${FMT[green]}OK${FMT[nc]}] Old job $JOB_NAME removed successfully."
    else
        echo -e "[${FMT[green]}OK${FMT[nc]}] Job $JOB_NAME does not exist."
    fi
    sleep 1
}

apply_manifest() {
    kubectl apply -f "$MANIFEST_PATH"
    echo -e "\n[${FMT[green]}OK${FMT[nc]}] Manifest applied successfully."
    sleep 1
}

wait_job_completion() {
    kubectl -n "$NAMESPACE" wait --for=condition=complete --timeout=300s "job/$JOB_NAME"
    kubectl -n "$NAMESPACE" logs "job/$JOB_NAME" -f
    echo -e "\n[${FMT[green]}OK${FMT[nc]}] Job $JOB_NAME completed successfully."
    sleep 1
}

remove_job() {
    kubectl -n "$NAMESPACE" delete job "$JOB_NAME" --ignore-not-found=true
    kubectl -n "$NAMESPACE" delete configmap "$CONFIGMAP_NAME" --ignore-not-found=true
    echo -e "\n[${FMT[green]}OK${FMT[nc]}] Job $JOB_NAME removed successfully."
}

main() {
    clear
    echo -e "${FMT[bold]}*** Creating Kubernetes job to initialize Postgres schema ***${FMT[nc]}"; sleep 0.25
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Checking if the job exists...${FMT[nc]}\n"; check_job
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Applying the job manifest...${FMT[nc]}\n"; apply_manifest
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Waiting for the job to complete...${FMT[nc]}\n"; wait_job_completion
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "${FMT[yellow]}Removing the job...${FMT[nc]}\n"; remove_job
    echo -e "\n${FMT[yellow]}========================================================================================${FMT[nc]}"
    echo -e "\n${FMT[bold]}Postgres schema init job completed successfully.${FMT[nc]}\n"
}

main