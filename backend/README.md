# eKrishi Backend (Node.js + Express)

This backend is a plain JavaScript Express API designed for deployment on Vercel (free tier), using PostgreSQL via `pg`.

## 1. Local development

```bash
cd backend
cp .env.example .env
# fill in DATABASE_URL in .env
npm install
node --env-file=.env api/index.js
# or: npx nodemon api/index.js
```

The API will run on port `3000` by default.

## 2. Test with curl

```bash
# Health
curl http://localhost:3000/health

# Register farmer
curl -X POST http://localhost:3000/farmers/upsert \
  -H "Content-Type: application/json" \
  -d '{"phone_number":"9876543210","full_name":"Test Farmer","district":"Tumkur"}'

# Push listing
curl -X POST http://localhost:3000/listings \
  -H "Content-Type: application/json" \
  -d '{"farmer_phone":"9876543210","produce_name":"Tomato","produce_name_local":"ಟೊಮೇಟೊ","quantity_kg":50,"price_per_kg":25.0,"grade":"A","location_district":"Tumkur"}'
```

## 3. Deploy to Vercel

- Install Vercel CLI: `npm i -g vercel`
- `cd backend && vercel`
- Add `DATABASE_URL` in Vercel dashboard -> Project Settings -> Environment Variables
- Every git push to `main` auto-deploys

## 4. Flutter .env update

- For Android emulator: `NEON_API_URL=http://10.0.2.2:3000`
- For physical device: `NEON_API_URL=http://<your-local-ip>:3000`
- For production: `NEON_API_URL=https://your-app.vercel.app`
