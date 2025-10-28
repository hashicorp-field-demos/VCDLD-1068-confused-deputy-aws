# Realm Information
output "realm_id" {
  description = "The ID of the Keycloak realm"
  value       = keycloak_realm.confused_deputy.id
}

output "realm_name" {
  description = "The name of the Keycloak realm"
  value       = keycloak_realm.confused_deputy.realm
}

# Products MCP Client
output "products_mcp_client_id" {
  description = "Client ID for Products MCP"
  value       = keycloak_openid_client.products_mcp.client_id
}

output "products_mcp_client_secret" {
  description = "Client secret for Products MCP"
  value       = keycloak_openid_client.products_mcp.client_secret
  sensitive   = true
}

# Products Agent Client
output "products_agent_client_id" {
  description = "Client ID for Products Agent"
  value       = keycloak_openid_client.products_agent.client_id
}

output "products_agent_client_secret" {
  description = "Client secret for Products Agent"
  value       = keycloak_openid_client.products_agent.client_secret
  sensitive   = true
}

# Products Web Client
output "products_web_client_id" {
  description = "Client ID for Products Web"
  value       = keycloak_openid_client.products_web.client_id
}

# User Group IDs (for Vault mapping)
output "dbread_group_id" {
  description = "ID of the dbread group"
  value       = keycloak_group.dbread.id
}

output "dbadmin_group_id" {
  description = "ID of the dbadmin group"
  value       = keycloak_group.dbadmin.id
}

output "dbread_group_name" {
  description = "Name of the dbread group"
  value       = keycloak_group.dbread.name
}

output "dbadmin_group_name" {
  description = "Name of the dbadmin group"
  value       = keycloak_group.dbadmin.name
}

# Scopes
output "products_mcp_scopes" {
  description = "List of Products MCP scopes"
  value = [
    keycloak_openid_client_scope.products_read.name,
    keycloak_openid_client_scope.products_write.name,
    keycloak_openid_client_scope.products_list.name,
    keycloak_openid_client_scope.products_delete.name,
  ]
}

output "products_agent_scopes" {
  description = "List of Products Agent scopes"
  value = [
    keycloak_openid_client_scope.agent_invoke.name,
  ]
}

# OIDC Endpoints
output "oidc_issuer_url" {
  description = "OIDC issuer URL for the realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.confused_deputy.realm}"
}

output "oidc_discovery_url" {
  description = "OIDC discovery URL for the realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.confused_deputy.realm}/.well-known/openid-configuration"
}

output "jwks_uri" {
  description = "JWKS URI for the realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.confused_deputy.realm}/protocol/openid-connect/certs"
}

output "token_endpoint" {
  description = "Token endpoint URL for the realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.confused_deputy.realm}/protocol/openid-connect/token"
}

output "authorization_endpoint" {
  description = "Authorization endpoint URL for the realm"
  value       = "${var.keycloak_url}/realms/${keycloak_realm.confused_deputy.realm}/protocol/openid-connect/auth"
}
