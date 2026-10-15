from __future__ import annotations

from typing import Literal, Optional

from pydantic import AliasChoices, BaseModel, ConfigDict, EmailStr, Field, field_validator, model_validator


class SuggestionRequest(BaseModel):
    model_config = ConfigDict(populate_by_name=True, str_strip_whitespace=True)

    nombre: str = Field("", max_length=120, validation_alias=AliasChoices("nombre", "citizen_name"))
    correo: Optional[EmailStr] = Field(None, validation_alias=AliasChoices("correo", "citizen_email"))
    tipo: str = Field("sugerencia", max_length=40, validation_alias=AliasChoices("tipo", "message_type"))
    mensaje: str = Field(..., min_length=5, max_length=3000, validation_alias=AliasChoices("mensaje", "content"))

    @field_validator("correo", mode="before")
    @classmethod
    def blank_email_is_none(cls, value):
        return None if value is None or str(value).strip() == "" else value


class ReportRequest(BaseModel):
    """Contrato JSON conservado para integraciones antiguas sin fotografías."""

    category: str = Field(..., min_length=2, max_length=80)
    subcategory: str = Field(..., min_length=2, max_length=120)
    priority_color: Literal["green", "yellow", "red"]
    latitude: float = Field(..., ge=-90, le=90)
    longitude: float = Field(..., ge=-180, le=180)
    address: str = Field(..., min_length=3, max_length=500)
    citizen_email: Optional[EmailStr] = None
    description: str = Field("Reporte recibido por integración JSON", min_length=3, max_length=3000)


class AdminLoginRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=80)
    password: str = Field(..., min_length=8, max_length=256)


class AdminPasswordChangeRequest(BaseModel):
    current_password: str = Field(..., min_length=8, max_length=256)
    new_password: str = Field(..., min_length=12, max_length=72)
    confirm_password: str = Field(..., min_length=12, max_length=72)

    @field_validator("new_password")
    @classmethod
    def validate_password_strength(cls, value: str) -> str:
        checks = (
            any(char.islower() for char in value),
            any(char.isupper() for char in value),
            any(char.isdigit() for char in value),
            any(not char.isalnum() for char in value),
        )
        if not all(checks):
            raise ValueError("La contraseña debe incluir mayúscula, minúscula, número y símbolo")
        if len(value.encode("utf-8")) > 72:
            raise ValueError("La contraseña no puede superar 72 bytes")
        return value

    @model_validator(mode="after")
    def validate_confirmation(self):
        if self.new_password != self.confirm_password:
            raise ValueError("La confirmación de la contraseña no coincide")
        if self.current_password == self.new_password:
            raise ValueError("La nueva contraseña debe ser diferente de la actual")
        return self


class AdminReportActionRequest(BaseModel):
    confirmacion: str = Field(..., min_length=8, max_length=45)

    @field_validator("confirmacion")
    @classmethod
    def normalize_filing_confirmation(cls, value: str) -> str:
        normalized = value.strip().upper()
        if not normalized or any(character not in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-" for character in normalized):
            raise ValueError("La confirmación del radicado no es válida")
        return normalized


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., min_length=20, max_length=4096)


class LogoutRequest(BaseModel):
    refresh_token: str = Field(..., min_length=20, max_length=4096)
