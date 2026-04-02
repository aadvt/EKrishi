from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from database import get_db
from models import FARMERS_TABLE, LISTINGS_TABLE
from schemas import ListingCreateRequest, ListingCreateResponse, ListingOut

router = APIRouter()


@router.post("", response_model=ListingCreateResponse, status_code=status.HTTP_201_CREATED)
async def create_listing(
    payload: ListingCreateRequest,
    db: AsyncSession = Depends(get_db),
) -> ListingCreateResponse:
    try:
        lookup_farmer_query = text(
            f"""
            SELECT farmer_id
            FROM {FARMERS_TABLE}
            WHERE phone_number = :phone_number
            LIMIT 1
            """
        )
        farmer_row = (
            await db.execute(
                lookup_farmer_query,
                {"phone_number": payload.farmer_phone},
            )
        ).mappings().first()

        if not farmer_row:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Farmer not registered. Please register first.",
            )

        farmer_id = str(farmer_row["farmer_id"])

        grade_source = "manual"
        source_channel = payload.source_channel if payload.source_channel == "web" else "web"

        listing_params = {
            "farmer_id": farmer_id,
            "commodity_name": payload.produce_name,
            "produce_description": payload.produce_name_local,
            "quantity_kg": payload.quantity_kg,
            "quantity_remaining_kg": payload.quantity_kg,
            "minimum_price_per_kg": (
                payload.price_min_per_kg
                if payload.price_min_per_kg is not None
                else payload.price_per_kg
            ),
            "fair_price_estimate": payload.price_per_kg,
            "grade": payload.grade,
            "grade_source": grade_source,
            "location_district": payload.location_district,
            "source_channel": source_channel,
            "latitude": payload.latitude,
            "longitude": payload.longitude,
        }

        if payload.latitude is not None and payload.longitude is not None:
            insert_listing_query = text(
                f"""
                INSERT INTO {LISTINGS_TABLE} (
                    farmer_id,
                    commodity_name,
                    produce_description,
                    quantity_kg,
                    quantity_remaining_kg,
                    minimum_price_per_kg,
                    fair_price_estimate,
                    grade,
                    grade_source,
                    delivery_terms,
                    status,
                    location_district,
                    source_channel,
                    geom
                )
                VALUES (
                    :farmer_id,
                    :commodity_name,
                    :produce_description,
                    :quantity_kg,
                    :quantity_remaining_kg,
                    :minimum_price_per_kg,
                    :fair_price_estimate,
                    :grade,
                    :grade_source,
                    'farm_pickup',
                    'active',
                    :location_district,
                    :source_channel,
                    ST_MakePoint(:longitude, :latitude)::geography
                )
                RETURNING listing_id, farmer_id, status, created_at
                """
            )
        else:
            insert_listing_query = text(
                f"""
                INSERT INTO {LISTINGS_TABLE} (
                    farmer_id,
                    commodity_name,
                    produce_description,
                    quantity_kg,
                    quantity_remaining_kg,
                    minimum_price_per_kg,
                    fair_price_estimate,
                    grade,
                    grade_source,
                    delivery_terms,
                    status,
                    location_district,
                    source_channel
                )
                VALUES (
                    :farmer_id,
                    :commodity_name,
                    :produce_description,
                    :quantity_kg,
                    :quantity_remaining_kg,
                    :minimum_price_per_kg,
                    :fair_price_estimate,
                    :grade,
                    :grade_source,
                    'farm_pickup',
                    'active',
                    :location_district,
                    :source_channel
                )
                RETURNING listing_id, farmer_id, status, created_at
                """
            )

        update_farmer_totals_query = text(
            f"""
            UPDATE {FARMERS_TABLE}
            SET total_listings = total_listings + 1,
                updated_at = now()
            WHERE farmer_id = :farmer_id
            """
        )

        listing_row = (
            await db.execute(insert_listing_query, listing_params)
        ).mappings().first()

        if not listing_row:
            await db.rollback()
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Failed to create listing",
            )

        await db.execute(update_farmer_totals_query, {"farmer_id": farmer_id})
        await db.commit()

        return ListingCreateResponse(
            listing_id=str(listing_row["listing_id"]),
            farmer_id=str(listing_row["farmer_id"]),
            status=str(listing_row["status"]),
            created_at=listing_row["created_at"],
        )
    except HTTPException:
        await db.rollback()
        raise
    except Exception as exc:
        await db.rollback()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to create listing: {exc}",
        ) from exc


@router.get("/{listing_id}", response_model=ListingOut)
async def get_listing(
    listing_id: str,
    db: AsyncSession = Depends(get_db),
) -> ListingOut:
    query = text(
        f"""
        SELECT
            listing_id,
            farmer_id,
            commodity_name AS produce_name,
            fair_price_estimate AS price_per_kg,
            minimum_price_per_kg AS price_min_per_kg,
            NULL::numeric AS price_max_per_kg,
            grade,
            location_district,
            source_channel,
            status,
            created_at
        FROM {LISTINGS_TABLE}
        WHERE listing_id = :listing_id
        LIMIT 1
        """
    )

    row = (await db.execute(query, {"listing_id": listing_id})).mappings().first()
    if not row:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Listing not found")

    return ListingOut(**row)
