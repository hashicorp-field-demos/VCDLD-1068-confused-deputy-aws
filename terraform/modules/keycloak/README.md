# Keycloak Authentication Module

This Terraform module configures a complete Keycloak realm with clients, users, groups, and token exchange capabilities for the Confused Deputy secure agentic application.

## Overview

The module creates:

- **Realm**: `confused-deputy-realm` - An isolated Keycloak realm for the application
- **Users**: 
  - `alice` - Read-only user (member of `dbread` group)
  - `bob` - Admin user (member of `dbadmin` group)
- **Groups**:
  - `dbread` - Maps to Vault's readonly policy
  - `dbadmin` - Maps to Vault's readwrite policy
- **Clients**:
  - `products-web` - Public client for the Streamlit web interface (PKCE flow)
  - `products-agent` - Confidential client for the FastAPI agent service
  - `products-mcp` - Confidential client for the MCP server
- **Scopes**:
  - `Products.Read`, `Products.Write`, `Products.List`, `Products.Delete` - MCP operations
  - `Agent.Invoke` - Agent invocation
- **Token Exchange**: Configured to allow products-agent to exchange tokens for products-mcp

## Prerequisites

Before using this module, you need:

1. **Keycloak Instance**: A running Keycloak server
   - Local development: Use the provided `docker-compose/keycloak/docker-compose.yml`
   - Production: Deploy Keycloak on your infrastructure

2. **Admin Credentials**: Keycloak admin username and password

## Usage

### Starting Keycloak Locally

```bash
cd docker-compose
docker-compose up -d keycloak

# Wait for Keycloak to be ready (about 30-60 seconds)
# Access admin console at http://localhost:8080
```

### Applying the Module

The module is already integrated into the main Terraform configuration:

```bash
cd terraform
terraform init
terraform apply
```

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `keycloak_url` | Base URL of Keycloak server | `http://localhost:8080` |
| `realm_name` | Name of the realm to create | `confused-deputy-realm` |
| `user_password` | Password for test users (alice, bob) | - (required) |
| `alb_https_url` | HTTPS URL for AWS ALB (for redirect URIs) | - (required) |

### Outputs

The module provides comprehensive outputs for integration:

**Client Information:**
- `products_mcp_client_id` / `products_mcp_client_secret`
- `products_agent_client_id` / `products_agent_client_secret`
- `products_web_client_id`

**OIDC Endpoints:**
- `oidc_issuer_url` - For JWT validation
- `oidc_discovery_url` - For automatic configuration
- `jwks_uri` - For token verification
- `token_endpoint` - For token exchange
- `authorization_endpoint` - For OAuth flows

**Group Information:**
- `dbread_group_id` / `dbread_group_name`
- `dbadmin_group_id` / `dbadmin_group_name`

## Integration with Vault

To integrate with HashiCorp Vault, uncomment the `vault_auth_keycloak` module in `terraform/main.tf`:

```hcl
module "vault_auth_keycloak" {
  source = "./modules/vault-auth"

  docdb_cluster_endpoint = module.aws_documentdb.cluster_endpoint
  docdb_username         = var.docdb_master_username
  docdb_password         = var.docdb_master_password

  jwt_oidc_discovery_url     = module.keycloak.oidc_discovery_url
  jwt_bound_issuer           = module.keycloak.oidc_issuer_url
  jwt_bound_audiences        = module.keycloak.products_mcp_client_id
  readonly_group_alias_name  = module.keycloak.dbread_group_name
  readwrite_group_alias_name = module.keycloak.dbadmin_group_name

  depends_on = [module.hcp_vault, module.keycloak]
}
```

## Testing Authentication

After applying the configuration:

1. **Access Keycloak Admin Console**:
   ```
   URL: http://localhost:8080
   Username: admin
   Password: admin
   ```

2. **Test Users**:
   - Username: `alice`, Password: `<your-configured-password>` (readonly access)
   - Username: `bob`, Password: `<your-configured-password>` (admin access)

3. **Verify Configuration**:
   - Navigate to the `confused-deputy-realm` realm
   - Check Clients: products-web, products-agent, products-mcp
   - Check Users and Groups
   - Verify Client Scopes and Mappers

## Token Exchange Flow

The module configures the following OAuth2 token exchange flow:

```
1. User authenticates via products-web (public client)
   └─> Receives access token with Agent.Invoke scope

2. products-web calls products-agent with user token
   └─> products-agent validates JWT

3. products-agent exchanges token for products-mcp token
   └─> Uses Keycloak token exchange grant type
   └─> Receives new token with Products.* scopes

4. products-agent calls products-mcp with exchanged token
   └─> products-mcp validates JWT and extracts groups
   └─> Groups are mapped to Vault policies via JWT auth
```

## Security Considerations

1. **Client Secrets**: The module generates client secrets which are marked as sensitive
2. **User Passwords**: Set strong passwords for production deployments
3. **HTTPS**: In production, Keycloak should only be accessed via HTTPS
4. **Token Lifespans**: Adjust token TTLs in the realm configuration as needed
5. **Group Mapping**: Groups are included in JWTs via protocol mappers

## Troubleshooting

### Keycloak Not Starting
```bash
# Check Keycloak logs
docker logs keycloak

# Verify health
curl http://localhost:8080/health
```

### Terraform Apply Fails
```bash
# Ensure Keycloak is running and accessible
curl http://localhost:8080/realms/master

# Check Terraform provider configuration
terraform console
> provider::keycloak
```

### Token Exchange Not Working
1. Verify `token-exchange` permission is granted to products-agent service account
2. Check client scopes are properly configured
3. Ensure `products-mcp` client has token exchange enabled

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Terraform Keycloak Provider](https://registry.terraform.io/providers/mrparkers/keycloak/latest/docs)
- [OAuth 2.0 Token Exchange](https://datatracker.ietf.org/doc/html/rfc8693)
