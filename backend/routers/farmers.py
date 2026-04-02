from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import FARMERS_TABLE
from schemas import FarmerOut, FarmerUpsertRequest, FarmerUpsertResponse

router = APIRouter()


@router.post("/upsert", response_model=FarmerUpsertResponse)
async def upsert_farmer(
    payload: FarmerUpsertRequest,
    db: AsyncSession = Depends(get_db),
) -> FarmerUpsertResponse:
    existing_query = text(
        f"""
        SELECT farmer_id, phone_number
        FROM {FARMERS_TABLE}
        WHERE phone_number = :phone_number
        LIMIT 1
        """
    )
    existing_row = (
        await db.execute(existing_query, {"phone_number": payload.phone_number})
    ).mappings().first()

    if existing_row:
        return FarmerUpsertResponse(
            farmer_id=str(existing_row["farmer_id"]),
            already_exists=True,
            phone_number=str(existing_row["phone_number"]),
        )

    if payload.latitude is not None and payload.longitude is not None:
        insert_query = text(
            f"""
            INSERT INTO {FARMERS_TABLE} (
                phone_number,
                full_name,
                district,
                taluk,
                village,
                geom
            )
            VALUES (
                :phone_number,
                :full_name,
                :district,
                :taluk,
                :village,
                ST_MakePoint(:longitude, :latitude)::geography
            )
            RETURNING farmer_id, phone_number
            """
        )
    else:
        insert_query = text(
            f"""
            INSERT INTO {FARMERS_TABLE} (
                phone_number,
                full_name,
                district,
                taluk,
                village
            )
            VALUES (
                :phone_number,
                :full_name,
                :district,
                :taluk,
                :village
            )
            RETURNING farmer_id, phone_number
            """
        )

    params = {
        "phone_number": payload.phone_number,
        "full_name": payload.full_name,
        "district": payload.district,
        "taluk": payload.taluk,
        "village": payload.village,
        "latitude": payload.latitude,
        "longitude": payload.longitude,
    }

    try:
        created_row = (await db.execute(insert_query, params)).mappings().first()
        if not created_row:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create farmer",
            )

        await db.commit()
        return FarmerUpsertResponse(
            farmer_id=str(created_row["farmer_id"]),
            already_exists=False,
            phone_number=str(created_row["phone_number"]),
        )
    except HTTPException:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to upsert farmer: {exc}",
        ) from exc


@router.get("/{phone_number}", response_model=FarmerOut)
async def get_farmer_by_phone(
    phone_number: str,
    db: AsyncSession = Depends(get_db),
) -> FarmerOut:
    query = text(
        f"""
        SELECT farmer_id, phone_number, full_name, district, taluk, village
        FROM {FARMERS_TABLE}
        WHERE phone_number = :phone_number
        LIMIT 1
        """
    )
    row = (await db.execute(query, {"phone_number": phone_number})).mappings().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Farmer not found")

    return FarmerOut(**row)
