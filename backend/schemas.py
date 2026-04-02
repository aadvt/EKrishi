from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field, field_validator


class FarmerUpsertRequest(BaseModel):
    phone_number: str
    full_name: str
    district: str
    taluk: str | None = None
    village: str | None = None
    latitude: float | None = None
    longitude: float | None = None

    @field_validator("phone_number")
    @classmethod
    def validate_phone_number(cls, value: str) -> str:
        phone = value.strip()
        if len(phone) != 10 or not phone.isdigit():
            raise ValueError("phone_number must be exactly 10 digits")
        return phone


class FarmerUpsertResponse(BaseModel):
    farmer_id: str
    already_exists: bool
    phone_number: str


class FarmerOut(BaseModel):
    farmer_id: str
    phone_number: str
    full_name: str
    district: str
    taluk: str | None = None
    village: str | None = None


class ListingCreateRequest(BaseModel):
    farmer_phone: str
    produce_name: str
    produce_name_local: str | None = None
    quantity_kg: float = 1.0
    price_per_kg: float
    price_min_per_kg: float | None = None
    price_max_per_kg: float | None = None
    grade: str | None = None
    location_district: str | None = None
    location_taluk: str | None = None
    latitude: float | None = None
    longitude: float | None = None
    source_channel: str = "mobile_app"

    @field_validator("farmer_phone")
    @classmethod
    def validate_farmer_phone(cls, value: str) -> str:
        phone = value.strip()
        if len(phone) != 10 or not phone.isdigit():
            raise ValueError("farmer_phone must be exactly 10 digits")
        return phone

    @field_validator("quantity_kg")
    @classmethod
    def validate_quantity(cls, value: float) -> float:
        if value <= 0:
            raise ValueError("quantity_kg must be greater than 0")
        return value

    @field_validator("price_per_kg")
    @classmethod
    def validate_price_per_kg(cls, value: float) -> float:
        if value <= 0:
            raise ValueError("price_per_kg must be greater than 0")
        return value


class ListingCreateResponse(BaseModel):
    listing_id: str
    farmer_id: str
    status: str
    created_at: datetime


class APIError(BaseModel):
    detail: str


class ListingOut(BaseModel):
    listing_id: str
    farmer_id: str
    produce_name: str
    price_per_kg: float
    price_min_per_kg: float | None = None
    price_max_per_kg: float | None = None
    grade: str | None = None
    location_district: str | None = None
    source_channel: str | None = None
    status: str | None = None
    created_at: datetime | None = None


class HealthResponse(BaseModel):
    status: str


class GenericMessage(BaseModel):
    message: str
    meta: dict[str, Any] | None = None
