import re

from pydantic import BaseModel, ConfigDict, Field, field_validator


_PHONE_ALLOWED = re.compile(r"^\+?[0-9()\-\s]+$")


def normalize_phone_number(value: str) -> str:
    phone = value.strip()
    if not phone or not _PHONE_ALLOWED.fullmatch(phone):
        raise ValueError("Enter a valid phone number.")

    has_international_prefix = phone.startswith("+")
    digits = re.sub(r"\D", "", phone)
    if not 3 <= len(digits) <= 15:
        raise ValueError("Phone number must contain between 3 and 15 digits.")

    return f"+{digits}" if has_international_prefix else digits


class EmergencyContactCreate(BaseModel):
    contact_name: str = Field(min_length=1, max_length=255)
    phone_number: str = Field(min_length=3, max_length=32)
    relationship: str | None = Field(default=None, max_length=100)
    priority: int = Field(default=1, ge=1, le=100)
    enabled: bool = True

    @field_validator("contact_name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        name = value.strip()
        if not name:
            raise ValueError("Contact name cannot be empty.")
        return name

    @field_validator("relationship")
    @classmethod
    def normalize_relationship(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str) -> str:
        return normalize_phone_number(value)


class EmergencyContactUpdate(BaseModel):
    contact_name: str | None = Field(default=None, min_length=1, max_length=255)
    phone_number: str | None = Field(default=None, min_length=3, max_length=32)
    relationship: str | None = Field(default=None, max_length=100)
    priority: int | None = Field(default=None, ge=1, le=100)
    enabled: bool | None = None

    @field_validator("contact_name")
    @classmethod
    def validate_name(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Contact name cannot be null.")
        name = value.strip()
        if not name:
            raise ValueError("Contact name cannot be empty.")
        return name

    @field_validator("relationship")
    @classmethod
    def normalize_relationship(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Phone number cannot be null.")
        return normalize_phone_number(value)

    @field_validator("priority", "enabled")
    @classmethod
    def reject_null_fields(cls, value):
        if value is None:
            raise ValueError("Field cannot be null.")
        return value


class EmergencyContactResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    contact_name: str
    phone_number: str
    relationship: str | None = Field(validation_alias="relationship_label")
    priority: int
    enabled: bool
