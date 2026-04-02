from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import farmers, listings

app = FastAPI(title="EKrishi Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


app.include_router(farmers.router, prefix="/farmers", tags=["farmers"])
app.include_router(listings.router, prefix="/listings", tags=["listings"])
