"""
Authentication controller for JWT validation and user management.
Supports Supabase/Firebase JWT tokens and user registration/profile management.
"""

import os
import jwt
import logging
import hashlib
import secrets
from typing import Dict, Any, Optional, List
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from .models import DatabaseManager, UserProfile
from .cache_service import CacheService

logger = logging.getLogger(__name__)


class AuthController:
    """Handles JWT token validation and user management for Supabase/Firebase authentication."""

    def __init__(self, db_manager: DatabaseManager = None, cache_service: CacheService = None):
        """Initialize auth controller with JWT configuration and dependencies."""
        self.jwt_secret = os.getenv("JWT_SECRET", "your-jwt-secret-key")
        self.jwt_algorithm = os.getenv("JWT_ALGORITHM", "HS256")
        self.supabase_jwt_secret = os.getenv("SUPABASE_JWT_SECRET")
        self.supabase_url = os.getenv("SUPABASE_URL")
        self.supabase_anon_key = os.getenv("SUPABASE_ANON_KEY")

        # Dependencies
        self.db_manager = db_manager
        self.cache_service = cache_service

        # Token configuration
        self.access_token_expire_hours = 24
        self.refresh_token_expire_days = 30

        # Password configuration
        self.min_password_length = 8
        self.require_special_chars = True

        logger.info("Auth controller initialized with user management capabilities")

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

    # User Management Methods

    def register_user(self, email: str, password: str, profile_data: Dict[str, Any] = None) -> Dict[str, Any]:
        """
        Register a new user with email and password.

        Args:
            email: User email address
            password: User password
            profile_data: Optional profile data (dialect, difficulty, etc.)

        Returns:
            Dict containing user data and tokens

        Raises:
            ValueError: If validation fails
            Exception: If registration fails
        """
        try:
            # Validate email and password
            self._validate_email(email)
            self._validate_password(password)

            # Check if user already exists
            if self._user_exists(email):
                raise ValueError("User with this email already exists")

            # Create user in database
            user_id = self._create_user_record(email, password, profile_data)

            # Generate tokens
            access_token = self._generate_access_token(user_id, email)
            refresh_token = self._generate_refresh_token(user_id)

            # Cache user session
            if self.cache_service:
                self.cache_service.set(f"user_session:{user_id}", {
                    "email": email,
                    "created_at": datetime.utcnow().isoformat()
                }, expire_minutes=1440)  # 24 hours

            logger.info(f"User registered successfully: {email}")
            return {
                "user_id": user_id,
                "email": email,
                "access_token": access_token,
                "refresh_token": refresh_token,
                "profile": profile_data or {}
            }

        except Exception as e:
            logger.error(f"User registration failed: {e}")
            raise

    def authenticate_user(self, email: str, password: str) -> Dict[str, Any]:
        """
        Authenticate user with email and password.

        Args:
            email: User email address
            password: User password

        Returns:
            Dict containing user data and tokens

        Raises:
            ValueError: If authentication fails
        """
        try:
            # Validate input
            if not email or not password:
                raise ValueError("Email and password are required")

            # Get user from database
            user_data = self._get_user_by_email(email)
            if not user_data:
                raise ValueError("Invalid email or password")

            # Verify password
            if not self._verify_password(password, user_data["password_hash"]):
                raise ValueError("Invalid email or password")

            user_id = user_data["user_id"]

            # Generate new tokens
            access_token = self._generate_access_token(user_id, email)
            refresh_token = self._generate_refresh_token(user_id)

            # Update last login
            self._update_last_login(user_id)

            # Cache user session
            if self.cache_service:
                self.cache_service.set(f"user_session:{user_id}", {
                    "email": email,
                    "last_login": datetime.utcnow().isoformat()
                }, expire_minutes=1440)

            logger.info(f"User authenticated successfully: {email}")
            return {
                "user_id": user_id,
                "email": email,
                "access_token": access_token,
                "refresh_token": refresh_token,
                "profile": user_data.get("profile", {})
            }

        except Exception as e:
            logger.error(f"Authentication failed: {e}")
            raise

    def refresh_tokens(self, refresh_token: str) -> Dict[str, Any]:
        """
        Refresh access token using refresh token.

        Args:
            refresh_token: Valid refresh token

        Returns:
            Dict containing new tokens

        Raises:
            ValueError: If refresh token is invalid
        """
        try:
            # Validate refresh token
            decoded_token = jwt.decode(
                refresh_token,
                self.jwt_secret,
                algorithms=[self.jwt_algorithm]
            )

            user_id = decoded_token.get("sub")
            if not user_id or decoded_token.get("type") != "refresh":
                raise ValueError("Invalid refresh token")

            # Get user data
            user_data = self._get_user_by_id(user_id)
            if not user_data:
                raise ValueError("User not found")

            # Generate new tokens
            access_token = self._generate_access_token(user_id, user_data["email"])
            new_refresh_token = self._generate_refresh_token(user_id)

            logger.info(f"Tokens refreshed for user: {user_id}")
            return {
                "access_token": access_token,
                "refresh_token": new_refresh_token
            }

        except jwt.InvalidTokenError:
            raise ValueError("Invalid refresh token")
        except Exception as e:
            logger.error(f"Token refresh failed: {e}")
            raise

    def logout_user(self, user_id: str) -> bool:
        """
        Logout user by invalidating session.

        Args:
            user_id: User identifier

        Returns:
            True if successful
        """
        try:
            # Clear user session cache
            if self.cache_service:
                self.cache_service.delete(f"user_session:{user_id}")

            # Update last logout time
            self._update_last_logout(user_id)

            logger.info(f"User logged out: {user_id}")
            return True

        except Exception as e:
            logger.error(f"Logout failed: {e}")
            return False

    def get_user_profile(self, user_id: str) -> Dict[str, Any]:
        """
        Get user profile data.

        Args:
            user_id: User identifier

        Returns:
            User profile data
        """
        try:
            if not self.db_manager:
                raise ValueError("Database manager not available")

            session = self.db_manager.get_session()
            try:
                # Get user profile
                profile = session.query(UserProfile).filter(
                    UserProfile.user_id == user_id
                ).first()

                if not profile:
                    # Return default profile
                    return {
                        "dialect": "lebanese",
                        "difficulty": "beginner",
                        "translit_style": {},
                        "settings": {}
                    }

                return {
                    "dialect": profile.preferred_level or "beginner",
                    "difficulty": profile.preferred_level or "beginner",
                    "translit_style": profile.settings.get("translit_style", {}),
                    "settings": profile.settings or {}
                }

            finally:
                session.close()

        except Exception as e:
            logger.error(f"Failed to get user profile: {e}")
            raise

    def update_user_profile(self, user_id: str, profile_data: Dict[str, Any]) -> bool:
        """
        Update user profile data.

        Args:
            user_id: User identifier
            profile_data: Profile data to update

        Returns:
            True if successful
        """
        try:
            if not self.db_manager:
                raise ValueError("Database manager not available")

            profile_repo = self.db_manager.get_profile_repository()
            profile_repo.update_profile(user_id, profile_data)

            logger.info(f"User profile updated: {user_id}")
            return True

        except Exception as e:
            logger.error(f"Failed to update user profile: {e}")
            raise

    # Helper Methods

    def _validate_email(self, email: str) -> bool:
        """Validate email format."""
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        if not re.match(pattern, email):
            raise ValueError("Invalid email format")
        return True

    def _validate_password(self, password: str) -> bool:
        """Validate password strength."""
        if len(password) < self.min_password_length:
            raise ValueError(f"Password must be at least {self.min_password_length} characters")

        if self.require_special_chars:
            import re
            if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
                raise ValueError("Password must contain at least one special character")

        return True

    def _hash_password(self, password: str) -> str:
        """Hash password using secure method."""
        # Generate random salt
        salt = secrets.token_hex(32)
        # Hash password with salt
        password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
        # Return salt + hash
        return salt + password_hash.hex()

    def _verify_password(self, password: str, stored_hash: str) -> bool:
        """Verify password against stored hash."""
        try:
            # Extract salt and hash
            salt = stored_hash[:64]
            stored_password_hash = stored_hash[64:]

            # Hash provided password with same salt
            password_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)

            # Compare hashes
            return password_hash.hex() == stored_password_hash

        except Exception:
            return False

    def _generate_access_token(self, user_id: str, email: str) -> str:
        """Generate access token."""
        payload = {
            "sub": user_id,
            "user_id": user_id,
            "email": email,
            "type": "access",
            "exp": datetime.utcnow() + timedelta(hours=self.access_token_expire_hours),
            "iat": datetime.utcnow(),
            "iss": "translator-tool"
        }
        return jwt.encode(payload, self.jwt_secret, algorithm=self.jwt_algorithm)

    def _generate_refresh_token(self, user_id: str) -> str:
        """Generate refresh token."""
        payload = {
            "sub": user_id,
            "type": "refresh",
            "exp": datetime.utcnow() + timedelta(days=self.refresh_token_expire_days),
            "iat": datetime.utcnow(),
            "iss": "translator-tool"
        }
        return jwt.encode(payload, self.jwt_secret, algorithm=self.jwt_algorithm)

    def _user_exists(self, email: str) -> bool:
        """Check if user exists by email."""
        try:
            if not self.db_manager:
                return False

            session = self.db_manager.get_session()
            try:
                # Simple check - would need proper User model
                return False  # Placeholder
            finally:
                session.close()
        except Exception:
            return False

    def _create_user_record(self, email: str, password: str, profile_data: Dict[str, Any] = None) -> str:
        """Create user record in database."""
        import uuid

        try:
            if not self.db_manager:
                raise ValueError("Database manager not available")

            user_id = str(uuid.uuid4())
            password_hash = self._hash_password(password)

            # Create user profile
            profile_repo = self.db_manager.get_profile_repository()
            default_profile = {
                "display_name": email.split("@")[0],
                "preferred_level": profile_data.get("difficulty", "beginner") if profile_data else "beginner",
                "settings": {
                    "dialect": profile_data.get("dialect", "lebanese") if profile_data else "lebanese",
                    "translit_style": profile_data.get("translit_style", {}) if profile_data else {},
                    "email": email,
                    "password_hash": password_hash
                }
            }

            profile_repo.update_profile(user_id, default_profile)

            return user_id

        except Exception as e:
            logger.error(f"Failed to create user record: {e}")
            raise

    def _get_user_by_email(self, email: str) -> Optional[Dict[str, Any]]:
        """Get user by email."""
        try:
            if not self.db_manager:
                return None

            session = self.db_manager.get_session()
            try:
                # Get all profiles and find by email in settings
                profile_repo = self.db_manager.get_profile_repository()
                # This is a simplified implementation
                # In production, you'd have a proper users table
                return None  # Placeholder
            finally:
                session.close()
        except Exception:
            return None

    def _get_user_by_id(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get user by ID."""
        try:
            profile = self.get_user_profile(user_id)
            return {
                "user_id": user_id,
                "email": profile.get("settings", {}).get("email"),
                "password_hash": profile.get("settings", {}).get("password_hash"),
                "profile": profile
            }
        except Exception:
            return None

    def _update_last_login(self, user_id: str) -> None:
        """Update user's last login time."""
        try:
            if self.db_manager:
                profile_repo = self.db_manager.get_profile_repository()
                profile_repo.update_profile(user_id, {
                    "last_login": datetime.utcnow()
                })
        except Exception as e:
            logger.warning(f"Failed to update last login: {e}")

    def _update_last_logout(self, user_id: str) -> None:
        """Update user's last logout time."""
        try:
            if self.db_manager:
                profile_repo = self.db_manager.get_profile_repository()
                profile_repo.update_profile(user_id, {
                    "last_logout": datetime.utcnow()
                })
        except Exception as e:
            logger.warning(f"Failed to update last logout: {e}")


# Exception Classes
class AuthenticationError(Exception):
    """Authentication related errors."""
    pass


class AuthorizationError(Exception):
    """Authorization related errors."""
    pass


class UserRegistrationError(Exception):
    """User registration related errors."""
    pass