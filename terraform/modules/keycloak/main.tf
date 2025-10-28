# Keycloak Realm
resource "keycloak_realm" "confused_deputy" {
  realm             = var.realm_name
  enabled           = true
  display_name      = "Confused Deputy Realm"
  display_name_html = "<b>Confused Deputy</b>"

  # Token settings
  access_token_lifespan               = "1h"
  access_token_lifespan_for_implicit_flow = "15m"
  sso_session_idle_timeout            = "30m"
  sso_session_max_lifespan            = "10h"
  offline_session_idle_timeout        = "720h"
  offline_session_max_lifespan        = "1440h"

  # Login settings
  login_with_email_allowed = true
  duplicate_emails_allowed = false
  reset_password_allowed   = true
  remember_me              = true
  verify_email             = false
  
  # Security settings
  ssl_required = "external"
}

# ========================================
# Realm Roles
# ========================================

resource "keycloak_role" "readonly" {
  realm_id    = keycloak_realm.confused_deputy.id
  name        = "readonly"
  description = "Read-only access to resources"
}

resource "keycloak_role" "admin" {
  realm_id    = keycloak_realm.confused_deputy.id
  name        = "admin"
  description = "Administrative access to resources"
}

# ========================================
# Users
# ========================================

resource "keycloak_user" "alice" {
  realm_id = keycloak_realm.confused_deputy.id
  username = "alice"
  enabled  = true

  email          = "alice@example.com"
  email_verified = true
  first_name     = "Alice"
  last_name      = "User"

  initial_password {
    value     = var.user_password
    temporary = false
  }
}

resource "keycloak_user" "bob" {
  realm_id = keycloak_realm.confused_deputy.id
  username = "bob"
  enabled  = true

  email          = "bob@example.com"
  email_verified = true
  first_name     = "Bob"
  last_name      = "Admin"

  initial_password {
    value     = var.user_password
    temporary = false
  }
}

# Assign roles to users
resource "keycloak_user_roles" "alice_roles" {
  realm_id = keycloak_realm.confused_deputy.id
  user_id  = keycloak_user.alice.id

  role_ids = [
    keycloak_role.readonly.id,
  ]
}

resource "keycloak_user_roles" "bob_roles" {
  realm_id = keycloak_realm.confused_deputy.id
  user_id  = keycloak_user.bob.id

  role_ids = [
    keycloak_role.admin.id,
  ]
}

# ========================================
# Groups (for Vault policy mapping)
# ========================================

resource "keycloak_group" "dbread" {
  realm_id = keycloak_realm.confused_deputy.id
  name     = "dbread"
}

resource "keycloak_group" "dbadmin" {
  realm_id = keycloak_realm.confused_deputy.id
  name     = "dbadmin"
}

# Add users to groups
resource "keycloak_group_memberships" "dbread_members" {
  realm_id = keycloak_realm.confused_deputy.id
  group_id = keycloak_group.dbread.id

  members = [
    keycloak_user.alice.username,
  ]
}

resource "keycloak_group_memberships" "dbadmin_members" {
  realm_id = keycloak_realm.confused_deputy.id
  group_id = keycloak_group.dbadmin.id

  members = [
    keycloak_user.bob.username,
  ]
}

# ========================================
# Products MCP Client (Resource Server)
# ========================================

resource "keycloak_openid_client" "products_mcp" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = "products-mcp"
  name      = "Products MCP Server"
  
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  service_accounts_enabled     = true
  standard_flow_enabled        = false
  direct_access_grants_enabled = false
  
  valid_redirect_uris = [
    "http://localhost:8000/*",
  ]
  
  web_origins = [
    "http://localhost:8000",
  ]
}

# Products MCP Client Scopes
resource "keycloak_openid_client_scope" "products_read" {
  realm_id               = keycloak_realm.confused_deputy.id
  name                   = "Products.Read"
  description            = "Read products"
  include_in_token_scope = true
  gui_order              = 1
}

resource "keycloak_openid_client_scope" "products_write" {
  realm_id               = keycloak_realm.confused_deputy.id
  name                   = "Products.Write"
  description            = "Write products"
  include_in_token_scope = true
  gui_order              = 2
}

resource "keycloak_openid_client_scope" "products_list" {
  realm_id               = keycloak_realm.confused_deputy.id
  name                   = "Products.List"
  description            = "List products"
  include_in_token_scope = true
  gui_order              = 3
}

resource "keycloak_openid_client_scope" "products_delete" {
  realm_id               = keycloak_realm.confused_deputy.id
  name                   = "Products.Delete"
  description            = "Delete products"
  include_in_token_scope = true
  gui_order              = 4
}

# Add scopes to products-mcp client
resource "keycloak_openid_client_optional_scopes" "products_mcp_scopes" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_mcp.id

  optional_scopes = [
    keycloak_openid_client_scope.products_read.name,
    keycloak_openid_client_scope.products_write.name,
    keycloak_openid_client_scope.products_list.name,
    keycloak_openid_client_scope.products_delete.name,
  ]
}

# ========================================
# Products Agent Client (Service)
# ========================================

resource "keycloak_openid_client" "products_agent" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = "products-agent"
  name      = "Products Agent API"
  
  enabled                      = true
  access_type                  = "CONFIDENTIAL"
  service_accounts_enabled     = true
  standard_flow_enabled        = true
  direct_access_grants_enabled = true
  
  valid_redirect_uris = [
    "http://localhost:8001/*",
  ]
  
  web_origins = [
    "http://localhost:8001",
  ]
}

# Products Agent Scope
resource "keycloak_openid_client_scope" "agent_invoke" {
  realm_id               = keycloak_realm.confused_deputy.id
  name                   = "Agent.Invoke"
  description            = "Invoke products agent"
  include_in_token_scope = true
  gui_order              = 1
}

# Add agent scope to products-agent client
resource "keycloak_openid_client_optional_scopes" "products_agent_scopes" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_agent.id

  optional_scopes = [
    keycloak_openid_client_scope.agent_invoke.name,
    keycloak_openid_client_scope.products_read.name,
    keycloak_openid_client_scope.products_write.name,
    keycloak_openid_client_scope.products_list.name,
    keycloak_openid_client_scope.products_delete.name,
  ]
}

# ========================================
# Products Web Client (Public Client)
# ========================================

resource "keycloak_openid_client" "products_web" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = "products-web"
  name      = "Products Web UI"
  
  enabled                      = true
  access_type                  = "PUBLIC"
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  implicit_flow_enabled        = false
  
  # PKCE support
  pkce_code_challenge_method = "S256"
  
  valid_redirect_uris = [
    "http://localhost:8501/oauth2callback",
    "${var.alb_https_url}/oauth2callback",
  ]
  
  web_origins = [
    "http://localhost:8501",
    var.alb_https_url,
  ]
  
  # Root and base URLs
  root_url = "http://localhost:8501"
  base_url = "/"
}

# Add agent invoke scope to products-web client
resource "keycloak_openid_client_optional_scopes" "products_web_scopes" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_web.id

  optional_scopes = [
    keycloak_openid_client_scope.agent_invoke.name,
  ]
}

# ========================================
# Protocol Mappers for Group Claims
# ========================================

# Group membership mapper for products-mcp
resource "keycloak_openid_group_membership_protocol_mapper" "products_mcp_groups" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_mcp.id
  name      = "groups-mapper"

  claim_name            = "groups"
  full_path             = false
  add_to_id_token       = true
  add_to_access_token   = true
  add_to_userinfo       = true
}

# Group membership mapper for products-agent
resource "keycloak_openid_group_membership_protocol_mapper" "products_agent_groups" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_agent.id
  name      = "groups-mapper"

  claim_name            = "groups"
  full_path             = false
  add_to_id_token       = true
  add_to_access_token   = true
  add_to_userinfo       = true
}

# Group membership mapper for products-web
resource "keycloak_openid_group_membership_protocol_mapper" "products_web_groups" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_web.id
  name      = "groups-mapper"

  claim_name            = "groups"
  full_path             = false
  add_to_id_token       = true
  add_to_access_token   = true
  add_to_userinfo       = true
}

# Audience mapper for products-agent to access products-mcp
resource "keycloak_openid_audience_protocol_mapper" "products_agent_audience" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_agent.id
  name      = "products-mcp-audience"

  included_client_audience = keycloak_openid_client.products_mcp.client_id
  add_to_id_token          = false
  add_to_access_token      = true
}

# ========================================
# Token Exchange Configuration
# ========================================

# Allow products-agent to exchange tokens for products-mcp
resource "keycloak_openid_client_permissions" "products_mcp_permissions" {
  realm_id  = keycloak_realm.confused_deputy.id
  client_id = keycloak_openid_client.products_mcp.id
  
  enabled = true
}

# Token exchange policy for products-agent
resource "keycloak_openid_client_service_account_role" "products_agent_token_exchange" {
  realm_id                = keycloak_realm.confused_deputy.id
  service_account_user_id = keycloak_openid_client.products_agent.service_account_user_id
  client_id               = keycloak_openid_client.products_mcp.id
  role                    = "token-exchange"
  
  depends_on = [
    keycloak_openid_client_permissions.products_mcp_permissions
  ]
}
