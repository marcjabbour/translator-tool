"""
Authentication controller for JWT validation.
Supports Supabase/Firebase JWT tokens.
"""

import os
import jwt
import logging
from typing import Dict, Any
from datetime import datetime

logger = logging.getLogger(__name__)


class AuthController:
    """Handles JWT token validation for Supabase/Firebase authentication."""

    def __init__(self):
        """Initialize auth controller with JWT configuration."""
        self.jwt_secret = os.getenv("JWT_SECRET", "your-jwt-secret-key")
        self.jwt_algorithm = os.getenv("JWT_ALGORITHM", "HS256")
        self.supabase_jwt_secret = os.getenv("SUPABASE_JWT_SECRET")

        # For production, use proper key fetching for Firebase/Supabase
        logger.info("Auth controller initialized")

    def validate_token(self, token: str) -> Dict[str, Any]:
        """
        Validate JWT token and extract user information.

        Args:
            token: JWT token string

        Returns:
            Decoded token payload with user data

        Raises:
            jwt.InvalidTokenError: If token is invalid or expired
            ValueError: If token format is invalid
        """
        try:
            # For development/testing, use simple JWT validation
            # In production, implement proper Supabase/Firebase key validation
            decoded_token = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=[self.jwt_algorithm],
                options={"verify_exp": True}
            )

            # Validate required fields
            if "sub" not in decoded_token and "user_id" not in decoded_token:
                raise ValueError("Token missing user identifier")

            # Check token expiration
            exp = decoded_token.get("exp")
            if exp and datetime.fromtimestamp(exp) < datetime.utcnow():
                raise jwt.ExpiredSignatureError("Token has expired")

            logger.info(f"Token validated for user: {decoded_token.get('sub', 'unknown')}")
            return decoded_token

        except jwt.ExpiredSignatureError:
            logger.warning("Token validation failed: expired")
            raise
        except jwt.InvalidTokenError as e:
            logger.warning(f"Token validation failed: {e}")
            raise
        except Exception as e:
            logger.error(f"Token validation error: {e}")
            raise ValueError(f"Token validation failed: {str(e)}")

    def validate_supabase_token(self, token: str) -> Dict[str, Any]:
        """
        Validate Supabase JWT token.

        Args:
            token: Supabase JWT token

        Returns:
            Decoded token payload

        Note:
            This is a placeholder for proper Supabase integration.
            In production, use Supabase's JWT verification with proper keys.
        """
        if not self.supabase_jwt_secret:
            # Fallback to regular JWT validation for development
            return self.validate_token(token)

        try:
            # Implement proper Supabase JWT validation here
            decoded_token = jwt.decode(
                token,
                self.supabase_jwt_secret,
                algorithms=["HS256"],
                audience="authenticated"
            )

            return decoded_token

        except Exception as e:
            logger.error(f"Supabase token validation failed: {e}")
            raise

    def create_test_token(self, user_id: str, exp_hours: int = 24) -> str:
        """
        Create a test JWT token for development.

        Args:
            user_id: User identifier
            exp_hours: Expiration time in hours

        Returns:
            Encoded JWT token
        """
        from datetime import datetime, timedelta

        payload = {
            "sub": user_id,
            "user_id": user_id,
            "exp": datetime.utcnow() + timedelta(hours=exp_hours),
            "iat": datetime.utcnow(),
            "iss": "translator-tool-dev"
        }

        token = jwt.encode(payload, self.jwt_secret, algorithm=self.jwt_algorithm)
        logger.info(f"Test token created for user: {user_id}")
        return token