#!/bin/bash

# This script generates .env files for Keycloak-based authentication.
# It accepts one argument: environment type.

# --- Argument Validation ---
if [ -z "$1" ]; then
    echo "Usage: $0 [local|docker|aws]"
    echo "  local:  Configure services to run on localhost."
    echo "  docker: Configure services to run in Docker containers."
    echo "  aws:    Configure services to run in Docker containers in AWS."
    exit 1
fi

ENV_TYPE=$1

if [ "$ENV_TYPE" != "local" ] && [ "$ENV_TYPE" != "docker" ] && [ "$ENV_TYPE" != "aws" ]; then
    echo "Error: Invalid environment type. Please use 'local', 'docker', or 'aws'."
    exit 1
fi

echo "Generating .env files for '$ENV_TYPE' environment with Keycloak authentication..."


# --- Environment-specific Variables ---
if [ "$ENV_TYPE" = "local" ]; then
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws"
    PRODUCTS_AGENT_URL="http://localhost:8001"
    PRODUCTS_MCP_SERVER_URL="http://localhost:8000/mcp"
    DB_HOST="localhost"
    REDIRECT_URI=http://localhost:8501/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_public_endpoint_url)
    ENV_FILE_NAME=".env"
    KEYCLOAK_URL="http://localhost:8080"
elif [ "$ENV_TYPE" = "aws" ]; then
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws/docker-compose"
    PRODUCTS_AGENT_URL="http://products-agent:8001"
    PRODUCTS_MCP_SERVER_URL="http://products-mcp:8000/mcp"
    DB_HOST=$(terraform output -state=$TF_STATE -raw documentdb_cluster_endpoint)
    REDIRECT_URI=$(terraform output -state=$TF_STATE -raw alb_https_url)/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_private_endpoint_url)
    ENV_FILE_NAME=".env"
    KEYCLOAK_URL="http://keycloak:8080"
else # docker
    ROOT_PATH="/Users/ravipanchal/learn/vault/confused-deputy-aws/docker-compose"
    PRODUCTS_AGENT_URL="http://products-agent:8001"
    PRODUCTS_MCP_SERVER_URL="http://products-mcp:8000/mcp"
    DB_HOST="$(ipconfig getifaddr en0)"
    REDIRECT_URI=http://localhost:8501/oauth2callback
    VAULT_ADDR=$(terraform output -state=$TF_STATE -raw vault_public_endpoint_url)
    ENV_FILE_NAME=".env.local"
    KEYCLOAK_URL="http://localhost:8080"
fi

export TF_STATE=/Users/ravipanchal/learn/vault/confused-deputy-aws/terraform/terraform.tfstate

# --- Keycloak Configuration ---
TENANT_ID=""
CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_web_client_id 2>/dev/null || echo "products-web")
CLIENT_SECRET=""
SCOPE="openid profile email $(terraform output -state=$TF_STATE -json products_agent_scopes 2>/dev/null | jq '. | join(" ")' -r)"
BASE_URL="${KEYCLOAK_URL}/realms/$(terraform output -state=$TF_STATE -raw keycloak_realm_name 2>/dev/null || echo "confused-deputy-realm")"

JWKS_URI=$(terraform output -state=$TF_STATE -raw keycloak_jwks_uri 2>/dev/null || echo "${KEYCLOAK_URL}/realms/confused-deputy-realm/protocol/openid-connect/certs")
JWT_ISSUER=$(terraform output -state=$TF_STATE -raw keycloak_oidc_issuer_url 2>/dev/null || echo "${KEYCLOAK_URL}/realms/confused-deputy-realm")
TOKEN_URL=$(terraform output -state=$TF_STATE -raw keycloak_token_endpoint 2>/dev/null || echo "${KEYCLOAK_URL}/realms/confused-deputy-realm/protocol/openid-connect/token")

PRODUCTS_AGENT_CLIENT_ID=$(terraform output -state=$TF_STATE -raw products_agent_client_id 2>/dev/null || echo "products-agent")
PRODUCTS_AGENT_CLIENT_SECRET=$(terraform output -state=$TF_STATE -raw products_agent_client_secret 2>/dev/null || echo "")
PRODUCTS_AGENT_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_agent_client_id 2>/dev/null || echo "products-agent")
PRODUCTS_AGENT_SCOPE=$(terraform output -state=$TF_STATE -json products_mcp_scopes 2>/dev/null | jq '. | join(" ")' -r)

PRODUCTS_MCP_AUDIENCE=$(terraform output -state=$TF_STATE -raw products_mcp_client_id 2>/dev/null || echo "products-mcp")

cat > $ROOT_PATH/products-web/$ENV_FILE_NAME <<WEBEOF
TENANT_ID=${TENANT_ID}
CLIENT_ID=${CLIENT_ID}
CLIENT_SECRET=${CLIENT_SECRET}
SCOPE="${SCOPE}"
REDIRECT_URI=${REDIRECT_URI}
BASE_URL=${BASE_URL}
PRODUCTS_AGENT_URL=${PRODUCTS_AGENT_URL}
LOG_LEVEL=info
WEBEOF

cat > $ROOT_PATH/products-agent/$ENV_FILE_NAME <<AGENTEOF
JWKS_URI=${JWKS_URI}
JWT_ISSUER=${JWT_ISSUER}
JWT_AUDIENCE=${PRODUCTS_AGENT_AUDIENCE}

# Keycloak OAuth Token Exchange Configuration
ENTRA_CLIENT_ID=${PRODUCTS_AGENT_CLIENT_ID}
ENTRA_CLIENT_SECRET=${PRODUCTS_AGENT_CLIENT_SECRET}
ENTRA_SCOPE="${PRODUCTS_AGENT_SCOPE}"
ENTRA_TOKEN_URL=${TOKEN_URL}

# Bedrock LLM configuration
BEDROCK_MODEL_ID=amazon.nova-pro-v1:0
BEDROCK_REGION=us-east-1

# MCP Server Configuration
PRODUCTS_MCP_SERVER_URL=${PRODUCTS_MCP_SERVER_URL}

LOG_LEVEL=info
AGENTEOF

cat > $ROOT_PATH/products-mcp/$ENV_FILE_NAME <<MCPEOF
# AWS DocumentDB Configuration
DB_HOST=${DB_HOST}
DB_PORT=27017
DB_NAME=test
COLLECTION_NAME=products

# MCP Server Configuration
SERVER_HOST=0.0.0.0
SERVER_PORT=8000
SERVER_NAME=products-mcp

# Application Settings
MAX_RESULTS=100

JWKS_URI=${JWKS_URI}
JWT_ISSUER=${JWT_ISSUER}
JWT_AUDIENCE=${PRODUCTS_MCP_AUDIENCE}
VAULT_ADDR=${VAULT_ADDR}
LOG_LEVEL=info
MCPEOF

if [ "$ENV_TYPE" = "docker" ]; then
    AWS_CREDS_FILE="$HOME/.aws/credentials"
    AGENT_ENV_FILE="$ROOT_PATH/products-agent/.env.local"
    if [ -f "$AWS_CREDS_FILE" ]; then
        ACCESS_KEY=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_access_key_id"{print $3}' "$AWS_CREDS_FILE")
        SECRET_KEY=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_secret_access_key"{print $3}' "$AWS_CREDS_FILE")
        SESSION_TOKEN=$(awk '/\[default\]/{f=1;next}/\[/{f=0}f && $1=="aws_session_token"{print $3}' "$AWS_CREDS_FILE")
        {
            echo "AWS_ACCESS_KEY_ID=$ACCESS_KEY"
            echo "AWS_SECRET_ACCESS_KEY=$SECRET_KEY"
            if [ -n "$SESSION_TOKEN" ]; then
                echo "AWS_SESSION_TOKEN=$SESSION_TOKEN"
            fi
        } >> "$AGENT_ENV_FILE"
        echo "Appended AWS credentials to $AGENT_ENV_FILE."
    else
        echo "Warning: $AWS_CREDS_FILE not found. AWS credentials not added to $AGENT_ENV_FILE."
    fi
fi

echo "Successfully generated $ENV_FILE_NAME files in $ROOT_PATH."
