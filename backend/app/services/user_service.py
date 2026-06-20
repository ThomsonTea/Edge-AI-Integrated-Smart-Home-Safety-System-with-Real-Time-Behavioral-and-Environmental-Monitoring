import os

import jwt
from datetime import datetime, timedelta
from dotenv import load_dotenv

from fastapi import HTTPException, status
from app.models.profile import Profile
from passlib.context import CryptContext
from sqlalchemy.orm import Session

load_dotenv()

OWNER_ROLE = "owner"
MANAGER_ROLE = "manager"
NORMAL_USER_ROLE = "normal_user"

ROLE_LABELS = {
    OWNER_ROLE: "Owner",
    MANAGER_ROLE: "Manager",
    NORMAL_USER_ROLE: "Normal User",
}

ROLE_ALIASES = {
    "owner": OWNER_ROLE,
    "admin": OWNER_ROLE,
    "administrator": OWNER_ROLE,
    "primary_owner": OWNER_ROLE,
    "manager": MANAGER_ROLE,
    "operator": MANAGER_ROLE,
    "normal_user": NORMAL_USER_ROLE,
    "normal user": NORMAL_USER_ROLE,
    "member": NORMAL_USER_ROLE,
    "guest": NORMAL_USER_ROLE,
    "resident": NORMAL_USER_ROLE,
    "user": NORMAL_USER_ROLE,
}


def normalize_role(value: str | None) -> str:
    normalized = (value or "").strip().lower().replace("-", "_")
    normalized = " ".join(normalized.split())

    if not normalized:
        return NORMAL_USER_ROLE

    normalized = normalized.replace("_", " ")
    role = ROLE_ALIASES.get(normalized)

    if role is None:
        raise ValueError("Unsupported user role.")

    return role


def is_owner(profile: Profile) -> bool:
    return normalize_role(profile.group_type) == OWNER_ROLE


def is_manager(profile: Profile) -> bool:
    return normalize_role(profile.group_type) == MANAGER_ROLE


def is_normal_user(profile: Profile) -> bool:
    return normalize_role(profile.group_type) == NORMAL_USER_ROLE


class UserService:
    # Secret key for JWT - in production, use environment variable
    SECRET_KEY = os.getenv("TOKEN_SECRET_KEY")
    ALGORITHM = os.getenv("ALGORITHM", "HS256")
    ACCESS_TOKEN_EXPIRE_MINUTES = 30

    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    def __init__(self, db: Session):
        self.db = db

    def create_user(
        self,
        username: str,
        password: str,
        email: str = None,
        phone_number: str = None,
        group_type: str = None,
        premise_id: int | None = None,
    ) -> Profile:
        role = normalize_role(group_type)
        hashed_password = self.hash_password(password)
        new_user = Profile(
            username=username,
            hash_password=hashed_password,
            email=email,
            phone_number=phone_number,
            group_type=role,
            premise_id=premise_id,
        )

        if self.db.query(Profile).filter(Profile.username == username).first():
            raise ValueError("User with this username already exists.")
        
        if len(password) < 6:
            raise ValueError("Password must be at least 6 characters long.")
        
        self.db.add(new_user)
        self.db.commit()
        self.db.refresh(new_user)
        return new_user

    def get_profile_by_token_payload(self, current_user: dict) -> Profile:
        user_id = current_user.get("user_id")
        profile = self.db.query(Profile).filter(Profile.id == user_id).first()

        if profile is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Current user profile not found",
            )

        return profile

    def owner_exists(self) -> bool:
        profiles = self.db.query(Profile).all()
        for profile in profiles:
            try:
                if is_owner(profile):
                    return True
            except ValueError:
                continue

        return False

    def require_owner(self, current_profile: Profile) -> None:
        if not is_owner(current_profile):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Owner access required.",
            )

    def require_owner_or_manager(self, current_profile: Profile) -> None:
        if not (is_owner(current_profile) or is_manager(current_profile)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="User management access denied.",
            )

    def can_manage_target_user(
        self,
        current_profile: Profile,
        target_profile: Profile,
    ) -> bool:
        if current_profile.premise_id is None:
            return False

        if target_profile.premise_id != current_profile.premise_id:
            return False

        if is_owner(target_profile):
            return False

        if is_owner(current_profile):
            return True

        if is_manager(current_profile):
            return is_normal_user(target_profile)

        return False

    def is_self_target(
        self,
        current_profile: Profile,
        target_profile: Profile,
    ) -> bool:
        current_id = getattr(current_profile, "id", None)
        target_id = getattr(target_profile, "id", None)
        return current_id is not None and current_id == target_id

    def validate_user_creation(
        self,
        *,
        current_profile: Profile,
        requested_role: str | None,
    ) -> str:
        self.require_owner_or_manager(current_profile)

        if current_profile.premise_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Current user is not assigned to a premise.",
            )

        role = normalize_role(requested_role)

        if role == OWNER_ROLE:
            if self.owner_exists():
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="An owner already exists.",
                )

            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Owner role cannot be assigned from User Access Management.",
            )

        if is_manager(current_profile) and role != NORMAL_USER_ROLE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Managers can only create normal users.",
            )

        return role

    def ensure_can_manage_user(
        self,
        *,
        current_profile: Profile,
        target_profile: Profile,
        owner_message: str = "Owner is protected.",
    ) -> None:
        self.require_owner_or_manager(current_profile)

        if is_owner(target_profile):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=owner_message,
            )

        if not self.can_manage_target_user(current_profile, target_profile):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot manage this user.",
            )

    def validate_managed_user_role_update(
        self,
        *,
        current_profile: Profile,
        target_profile: Profile,
        requested_role: str | None,
    ) -> str:
        if requested_role is None:
            return normalize_role(target_profile.group_type)

        try:
            role = normalize_role(requested_role)
        except ValueError as error:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(error),
            ) from error

        if role == OWNER_ROLE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Owner role cannot be assigned from User Access Management.",
            )

        if is_manager(current_profile) and role != NORMAL_USER_ROLE:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Managers can only manage normal users.",
            )

        return role

    def update_managed_user(
        self,
        *,
        current_profile: Profile,
        target_profile: Profile,
        username: str | None = None,
        email: str | None = None,
        phone_number: str | None = None,
        group_type: str | None = None,
    ) -> Profile:
        if self.is_self_target(current_profile, target_profile):
            if group_type is not None:
                try:
                    requested_role = normalize_role(group_type)
                except ValueError as error:
                    raise HTTPException(
                        status_code=status.HTTP_400_BAD_REQUEST,
                        detail=str(error),
                    ) from error

                if requested_role != normalize_role(target_profile.group_type):
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail="You cannot change your own role from User Management.",
                    )

            return self._update_profile_basic_fields(
                target_profile=target_profile,
                username=username,
                email=email,
                phone_number=phone_number,
            )

        self.ensure_can_manage_user(
            current_profile=current_profile,
            target_profile=target_profile,
            owner_message="Owner cannot be edited from User Management.",
        )

        target_profile.group_type = self.validate_managed_user_role_update(
            current_profile=current_profile,
            target_profile=target_profile,
            requested_role=group_type,
        )

        return self._update_profile_basic_fields(
            target_profile=target_profile,
            username=username,
            email=email,
            phone_number=phone_number,
        )

    def _update_profile_basic_fields(
        self,
        *,
        target_profile: Profile,
        username: str | None = None,
        email: str | None = None,
        phone_number: str | None = None,
    ) -> Profile:
        if username is not None:
            next_username = username.strip()
            if not next_username:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username cannot be empty.",
                )

            existing = (
                self.db.query(Profile)
                .filter(Profile.username == next_username, Profile.id != target_profile.id)
                .first()
            )
            if existing is not None:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Username already exists.",
                )

            target_profile.username = next_username

        if email is not None:
            next_email = email.strip()
            if not next_email:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Email cannot be empty.",
                )

            target_profile.email = next_email

        if phone_number is not None:
            target_profile.phone_number = phone_number.strip() or None

        self.db.commit()
        self.db.refresh(target_profile)
        return target_profile

    def ensure_can_delete_user(
        self,
        *,
        current_profile: Profile,
        target_profile: Profile,
    ) -> None:
        self.require_owner_or_manager(current_profile)

        if is_owner(target_profile):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Owner cannot be deleted.",
            )

        if not self.can_manage_target_user(current_profile, target_profile):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="You cannot manage this user.",
            )

    def reset_managed_user_password(
        self,
        *,
        current_profile: Profile,
        target_profile: Profile,
        new_password: str,
        confirm_password: str,
    ) -> None:
        self.ensure_can_manage_user(
            current_profile=current_profile,
            target_profile=target_profile,
            owner_message="Owner password cannot be reset from User Management.",
        )

        if len(new_password) < 6:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password must be at least 6 characters long.",
            )

        if new_password != confirm_password:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="New password and confirm password do not match.",
            )

        target_profile.hash_password = self.hash_password(new_password)
        self.db.commit()

    def hash_password(self, password: str) -> str:
        return self.pwd_context.hash(password)

    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        return self.pwd_context.verify(plain_password, hashed_password)

    def authenticate_user(self, username: str, password: str) -> Profile:
        # Search the Profile table in the DB
        user = self.db.query(Profile).filter(Profile.username == username).first()
        
        if user and self.verify_password(password, user.hash_password):
            return user
        return None
    
    def create_access_token(self, user_id: int, username: str, group_type: str = None):
        """Generate a JWT token for the user"""
        role = normalize_role(group_type)
        payload = {
            "user_id": user_id,
            "username": username,
            "role": role,
            "exp": datetime.utcnow() + timedelta(minutes=self.ACCESS_TOKEN_EXPIRE_MINUTES),
            "iat": datetime.utcnow()
        }
        token = jwt.encode(payload, self.SECRET_KEY, algorithm=self.ALGORITHM)
        return token
