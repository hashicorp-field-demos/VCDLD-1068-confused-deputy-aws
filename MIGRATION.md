# Migration Guide: Microsoft Entra ID to Keycloak

This guide explains how to migrate from Microsoft Entra ID to Keycloak authentication.

## Why Migrate to Keycloak?

**Benefits of Keycloak:**
- ✅ No cloud dependencies - runs anywhere
- ✅ Free and open-source
- ✅ Fully automated setup with Terraform
- ✅ Perfect for development and testing
- ✅ Complete control over user management

**When to Keep Entra ID:**
- Enterprise SSO integration required
- Existing Azure AD infrastructure
- Conditional access policies needed
- Production deployments with Azure ecosystem

## Prerequisites

Before migrating, ensure you have:

1. **Docker** (for running Keycloak locally)
2. **Terraform** (already installed)
3. **Access to existing deployment** (to backup configuration)

## ⚠️ Security Considerations

**For Development/Testing:**
- Default credentials (admin/admin, password) are acceptable
- HTTP connections are acceptable for localhost

**For Production Deployments:**
- ❌ **NEVER** use default credentials
- ✅ Use strong, unique passwords for all accounts
- ✅ Enable HTTPS/TLS for Keycloak
- ✅ Configure Keycloak password policies
- ✅ Enable audit logging
- ✅ Restrict network access to Keycloak
- ✅ Regular security updates and backups
- ✅ Consider using external secrets management (e.g., Vault) for credentials

**This guide uses development credentials for simplicity. Always follow security best practices for production.**

## Migration Steps

### Step 1: Backup Current Configuration

```bash
# Backup current .env files
cp products-web/.env products-web/.env.entra.backup
cp products-agent/.env products-agent/.env.entra.backup
cp products-mcp/.env products-mcp/.env.entra.backup

# Backup Terraform state (optional but recommended)
cd terraform
cp terraform.tfstate terraform.tfstate.backup
```

### Step 2: Start Keycloak

```bash
cd docker-compose
docker-compose up -d keycloak

# Wait for Keycloak to be ready (30-60 seconds)
docker logs keycloak -f
# Look for: "Keycloak ... started"
```

Verify Keycloak is running:
```bash
curl http://localhost:8080/health
# Should return: {"status":"UP"}
```

### Step 3: Update Terraform Configuration

Edit `terraform/main.tf`:

```hcl
# Comment out the existing vault_auth module
# module "vault_auth" {
#   source = "./modules/vault-auth"
#   ...
# }

# Uncomment the vault_auth_keycloak module
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

Edit `terraform/terraform.tfvars`:

```hcl
# Add Keycloak configuration
keycloak_url            = "http://localhost:8080"
keycloak_admin_username = "admin"
keycloak_admin_password = "admin"  # ⚠️ CHANGE FOR PRODUCTION!
ad_user_password        = "password"  # ⚠️ CHANGE FOR PRODUCTION! Password for test users alice and bob

# Comment out or remove Entra ID configuration
# azure_client_id     = "..."
# azure_client_secret = "..."
# azure_tenant_id     = "..."
# jwt_oidc_discovery_url = "..."
# jwt_bound_issuer       = "..."
```

> **⚠️ Security Warning**: The default credentials shown above are for development/testing only. 
> For production deployments:
> - Change Keycloak admin password to a strong, unique password
> - Use strong passwords for all user accounts
> - Enable HTTPS for Keycloak
> - Consider using Keycloak's password policies

### Step 4: Apply Terraform Changes

```bash
cd terraform
terraform init  # Re-initialize to load Keycloak provider
terraform plan  # Review changes
terraform apply # Apply configuration
```

This will:
- Create the `confused-deputy-realm` in Keycloak
- Create users: alice (readonly), bob (admin)
- Create groups: dbread, dbadmin
- Create clients: products-web, products-agent, products-mcp
- Configure token exchange
- Update Vault JWT auth to use Keycloak

### Step 5: Generate New Environment Files

```bash
cd terraform

# For local development
./export-env.sh local keycloak

# For Docker Compose
./export-env.sh docker keycloak

# For AWS deployment
./export-env.sh aws keycloak
```

### Step 6: Restart Applications

**For local development:**
```bash
# Stop existing services (Ctrl+C)

# Restart products-mcp
cd products-mcp
source .venv/bin/activate
uv run python server.py

# Restart products-agent (new terminal)
cd products-agent
source .venv/bin/activate
uv run uvicorn main:app --host 0.0.0.0 --port 8001

# Restart products-web (new terminal)
cd products-web
source .venv/bin/activate
uv run streamlit run app.py
```

**For Docker Compose:**
```bash
cd docker-compose
docker-compose restart
```

### Step 7: Test Authentication

1. **Access the Web UI**: http://localhost:8501

2. **Click "Login with Keycloak"**

3. **Test with Alice (readonly)**:
   - Username: `alice`
   - Password: `password` (or the password you configured in terraform.tfvars)
   - Try queries: "Show me all products"
   - Should have read-only access

4. **Test with Bob (admin)**:
   - Username: `bob`
   - Password: `password` (or the password you configured in terraform.tfvars)
   - Try queries: "Create a new product..."
   - Should have full access

> **📝 Note**: For production deployments, always use strong, unique passwords and enable Keycloak's password policies.

### Step 8: Verify Token Exchange

Check the logs to verify token exchange is working:

```bash
# Check products-agent logs
docker logs products-agent -f
# or for local: check terminal output

# Look for:
# "Using Keycloak token service"
# "Successfully exchanged token with Keycloak"

# Check products-mcp logs
docker logs products-mcp -f

# Look for JWT validation messages
```

### Step 9: Verify Vault Integration

```bash
# Set Vault environment
export VAULT_ADDR=$(cd terraform && terraform output -raw vault_public_endpoint_url)
export VAULT_TOKEN=$(cd terraform && terraform output -raw vault_admin_token)

# Check JWT auth backend
vault read auth/jwt/config

# Verify groups
vault read identity/group/name/readonly
vault read identity/group/name/readwrite
```

## Rollback Procedure

If you need to rollback to Entra ID:

```bash
# Restore .env files
cp products-web/.env.entra.backup products-web/.env
cp products-agent/.env.entra.backup products-agent/.env
cp products-mcp/.env.entra.backup products-mcp/.env

# Restore Terraform configuration
cd terraform
# Edit main.tf to uncomment vault_auth, comment vault_auth_keycloak
# Edit terraform.tfvars to restore Entra ID configuration

# Apply changes
terraform apply

# Restart applications
```

## Troubleshooting

### Issue: Keycloak not accessible

```bash
# Check Keycloak status
docker ps | grep keycloak
docker logs keycloak

# Restart if needed
docker-compose restart keycloak
```

### Issue: Terraform fails with "connection refused"

**Solution**: Ensure Keycloak is running and accessible:
```bash
curl http://localhost:8080/realms/master
```

> **📝 Note**: For production deployments, always use HTTPS instead of HTTP. Configure TLS certificates in Keycloak and update the `keycloak_url` to use `https://`.

### Issue: Login button shows "Login with Microsoft"

**Solution**: The detection is based on BASE_URL in .env. Regenerate env files:
```bash
./terraform/export-env.sh local keycloak
```

### Issue: Token exchange fails

**Solution**: 
1. Check products-agent has client secret set
2. Verify token exchange permission in Keycloak admin console
3. Check MCP client allows token exchange

### Issue: User groups not working

**Solution**:
1. Verify users are assigned to groups in Keycloak
2. Check group membership protocol mapper is configured
3. Decode JWT token to verify groups claim is present

## Differences Between Providers

| Feature | Entra ID | Keycloak |
|---------|----------|----------|
| Deployment | Cloud (Azure) | Self-hosted |
| Cost | Pay per user | Free |
| Setup Time | Manual Azure setup | Automated Terraform |
| User Management | Azure Portal | Keycloak Admin Console |
| Token Exchange | On-Behalf-Of flow | OAuth2 Token Exchange |
| Group Claims | Security Groups | Keycloak Groups |
| OIDC Discovery | ✅ | ✅ |
| PKCE Support | ✅ | ✅ |

## Post-Migration Checklist

- [ ] Keycloak is running and accessible
- [ ] Terraform applied successfully
- [ ] Environment files regenerated
- [ ] Applications restarted
- [ ] Web UI shows "Login with Keycloak"
- [ ] Alice can login (readonly)
- [ ] Bob can login (admin)
- [ ] Token exchange working (check logs)
- [ ] Database credentials dynamic (check Vault)
- [ ] Groups mapped correctly
- [ ] Old .env backups saved
- [ ] Terraform state backed up

## Need Help?

- **Keycloak Docs**: https://www.keycloak.org/documentation
- **Terraform Provider**: https://registry.terraform.io/providers/mrparkers/keycloak
- **Module README**: See `terraform/modules/keycloak/README.md`

## Clean Up (Optional)

If you want to completely remove Entra ID components:

```bash
cd terraform

# Comment out or remove module "azure_ad_app" in main.tf
# Remove Azure AD related outputs from outputs.tf
# Remove Azure AD variables from terraform.tfvars

terraform apply
```

Note: Keep the module if you want to maintain the ability to switch back.
