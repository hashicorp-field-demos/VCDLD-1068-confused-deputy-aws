variable "keycloak_url" {
  description = "The base URL of the Keycloak server"
  type        = string
  default     = "http://localhost:8080"
}

variable "realm_name" {
  description = "Name of the Keycloak realm to create"
  type        = string
  default     = "confused-deputy-realm"
}

variable "user_password" {
  description = "Default password for test users (alice, bob)"
  type        = string
  sensitive   = true
}

variable "alb_https_url" {
  description = "HTTPS URL of the Application Load Balancer"
  type        = string
}
