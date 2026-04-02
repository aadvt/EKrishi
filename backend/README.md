# EKrishi FastAPI Backend

This backend sits between the Flutter app and Neon PostgreSQL.

## Setup

1. Create a Python virtual environment.
2. Install dependencies:

```bash
pip install -r requirements.txt
```

3. Copy `.env.example` to `.env` and set `DATABASE_URL`.

## Run locally

### Option 1: using script

```bash
bash run_local.sh
```

### Option 2: manual run

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

Backend runs at `http://localhost:8000`.

## Test with curl

```bash
curl -X POST http://localhost:8000/farmers/upsert \
	-H "Content-Type: application/json" \
	-d '{"phone_number":"9876543210","full_name":"Test Farmer","district":"Tumkur"}'
```

```bash
curl -X POST http://localhost:8000/listings \
	-H "Content-Type: application/json" \
	-d '{"farmer_phone":"9876543210","produce_name":"Tomato","produce_name_local":"ಟೊಮೇಟೊ","quantity_kg":50,"price_per_kg":25.0,"grade":"A","location_district":"Tumkur"}'
```

## Deploy to Render (free tier)

1. Connect your GitHub repository in Render.
2. Set Root Directory to `backend/`.
3. Build Command: `pip install -r requirements.txt`
4. Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. Add `DATABASE_URL` in Render environment variables.

## Endpoints

- `GET /health`
- `POST /farmers/upsert`
- `GET /farmers/{phone_number}`
- `POST /listings`
- `GET /listings/{listing_id}`

## Notes

- Uses async SQLAlchemy sessions (`asyncpg` driver).
- Uses SQLAlchemy Core text queries only.
- Does not create/alter tables.
- CORS allows all origins for mobile consumption.
