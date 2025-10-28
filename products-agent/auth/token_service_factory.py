"""
Token service factory to support both Entra ID and Keycloak authentication.
"""
import logging
import os
from typing import Protocol

logger = logging.getLogger(__name__)


class TokenService(Protocol):
    """Protocol defining the token service interface."""
    
    async def exchange_token_on_behalf_of(self, user_token: str) -> str:
        """Exchange user token for on-behalf-of token."""
        ...


def get_token_service() -> TokenService:
    """
    Factory function to get the appropriate token service based on configuration.
    
    Detects whether to use Entra ID or Keycloak based on the BASE_URL or TOKEN_URL environment variable.
    
    Returns:
        TokenService: An instance of either EntraTokenService or KeycloakTokenService
    """
    token_url = os.getenv("ENTRA_TOKEN_URL", "")
    
    # Detect if using Keycloak by checking for 'realms' in the token URL
    # Keycloak URLs typically contain '/realms/{realm-name}'
    is_keycloak = "realms" in token_url.lower() or "keycloak" in token_url.lower()
    
    if is_keycloak:
        logger.info("Using Keycloak token service")
        from .keycloak_token_service import get_keycloak_token_service
        return get_keycloak_token_service()
    else:
        logger.info("Using Entra ID token service")
        from .entra_token_service import get_entra_token_service
        return get_entra_token_service()
