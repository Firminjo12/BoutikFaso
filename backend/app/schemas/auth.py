from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=160)
    email: str | None = Field(default=None, max_length=320)
    phone: str | None = Field(default=None, max_length=32)
    password: str = Field(min_length=12, max_length=128)
    merchant_name: str = Field(min_length=2, max_length=160)

    @field_validator("full_name", "merchant_name")
    @classmethod
    def normalize_required_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Ce champ ne peut pas être vide.")
        return value

    @field_validator("email")
    @classmethod
    def normalize_email(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip().lower()
        if not value:
            return None
        if value.count("@") != 1 or "." not in value.rsplit("@", 1)[-1]:
            raise ValueError("Adresse e-mail invalide.")
        return value

    @field_validator("phone")
    @classmethod
    def normalize_phone(cls, value: str | None) -> str | None:
        value = value.strip() if value else None
        return value or None

    @model_validator(mode="after")
    def require_login_identifier(self) -> "RegisterRequest":
        if self.email is None and self.phone is None:
            raise ValueError("Indiquez une adresse e-mail ou un numéro de téléphone.")
        return self


class RefreshRequest(BaseModel):
    refresh_token: str = Field(min_length=20, max_length=4096)


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    active_merchant_id: UUID | None = None


class UserRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    full_name: str
    email: str | None
    phone: str | None


class MerchantCreate(BaseModel):
    name: str = Field(min_length=2, max_length=160)
    phone: str | None = Field(default=None, max_length=32)
    address: str | None = Field(default=None, max_length=255)

    @field_validator("name")
    @classmethod
    def normalize_name(cls, value: str) -> str:
        value = " ".join(value.split())
        if not value:
            raise ValueError("Le nom de la boutique est obligatoire.")
        return value


class MerchantRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    phone: str | None
    address: str | None
    currency: str
    timezone: str


class MerchantMembershipRead(BaseModel):
    merchant: MerchantRead
    role: str
    is_active: bool
    joined_at: datetime


class MeResponse(BaseModel):
    user: UserRead
    active_merchant: MerchantRead | None
    role: str | None
