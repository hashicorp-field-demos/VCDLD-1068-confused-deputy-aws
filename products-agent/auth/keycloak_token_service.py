import logging
import os
from typing import Any, Dict, Optional

import httpx
from fastapi import HTTPException, status

logger = logging.getLogger(__name__)


class KeycloakTokenService:
    """Service for exchanging tokens using Keycloak token exchange."""
    
    _instance: Optional["KeycloakTokenService"] = None
    _initialized = False

    def __init__(self):
        if not KeycloakTokenService._initialized:
            self.client_id = os.getenv("ENTRA_CLIENT_ID")  # Reusing env var name for compatibility
            self.client_secret = os.getenv("ENTRA_CLIENT_SECRET")
            self.scope = os.getenv("ENTRA_SCOPE")
            self.token_url = os.getenv("ENTRA_TOKEN_URL")

            if not all(
                [self.client_id, self.client_secret, self.scope, self.token_url]
            ):
                raise ValueError(
                    "Missing required Keycloak configuration in environment variables"
                )

            KeycloakTokenService._initialized = True

    @classmethod
    def get_instance(cls) -> "KeycloakTokenService":
        """
        Get the singleton instance of KeycloakTokenService.

        Returns:
            KeycloakTokenService: The singleton instance
        """
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    async def exchange_token_on_behalf_of(self, user_token: str) -> str:
        """
        Exchange user token for on-behalf-of token using Keycloak token exchange.

        Args:
            user_token (str): The user's JWT token

        Returns:
            str: On-behalf-of access token

        Raises:
            HTTPException: If token exchange fails
        """
        try:
            headers = {
                "Content-Type": "application/x-www-form-urlencoded",
                "Accept": "application/json",
            }

            # Keycloak token exchange request
            data = {
                "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "subject_token": user_token,
                "subject_token_type": "urn:ietf:params:oauth:token-type:access_token",
                "requested_token_type": "urn:ietf:params:oauth:token-type:access_token",
                "audience": self.scope.split()[0] if self.scope else "",  # Use first scope as audience
            }

            logger.info(f"Exchanging token with Keycloak at {self.token_url}")

            async with httpx.AsyncClient() as client:
                response = await client.post(
                    self.token_url, headers=headers, data=data, timeout=30.0
                )

                if response.status_code == 200:
                    token_response = response.json()
                    access_token = token_response.get("access_token")

                    if not access_token:
                        logger.error("No access_token in response from Keycloak")
                        raise HTTPException(
                            status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Failed to obtain access token from token exchange",
                        )

                    logger.info("Successfully exchanged token with Keycloak")
                    return access_token
                else:
                    error_details = self._extract_error_details(response)
                    logger.error(f"Token exchange failed: {error_details}")
                    raise HTTPException(
                        status_code=status.HTTP_401_UNAUTHORIZED,
                        detail=f"Token exchange failed: {error_details}",
                    )

        except httpx.RequestError as e:
            logger.error(f"Network error during token exchange: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Network error during token exchange: {str(e)}",
            )
        except Exception as e:
            logger.error(f"Unexpected error during token exchange: {str(e)}")
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Unexpected error during token exchange: {str(e)}",
            )

    def _extract_error_details(self, response: httpx.Response) -> str:
        """
        Extract error details from failed token exchange response.

        Args:
            response (httpx.Response): Failed HTTP response

        Returns:
            str: Error details string
        """
        try:
            error_data = response.json()
            error_description = error_data.get("error_description", "Unknown error")
            error_code = error_data.get("error", "unknown_error")
            return f"{error_code}: {error_description}"
        except Exception:
            return f"HTTP {response.status_code}: {response.text}"


# Lazy-loaded singleton instance
_keycloak_token_service = None

def get_keycloak_token_service() -> KeycloakTokenService:
    """Get the singleton KeycloakTokenService instance."""
    global _keycloak_token_service
    if _keycloak_token_service is None:
        _keycloak_token_service = KeycloakTokenService()
    return _keycloak_token_service
