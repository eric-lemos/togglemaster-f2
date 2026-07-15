#!/bin/bash
set -e

# Cria os bancos de dados necessários para os serviços
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    CREATE DATABASE auth_db;
    CREATE DATABASE flags_db;
    CREATE DATABASE targeting_db;
EOSQL

# Aplica o schema do auth-service
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "auth_db" \
    -f /init/auth-init.sql

# Aplica o schema do flag-service
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "flags_db" \
    -f /init/flag-init.sql

# Aplica o schema do targeting-service
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "targeting_db" \
    -f /init/targeting-init.sql