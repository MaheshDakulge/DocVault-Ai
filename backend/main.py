from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import scan, assistant, sync, share, auth
from core.middleware import RateLimitMiddleware

app = FastAPI(
    title="DocsVault AI Backend",
    description="FastAPI backend for DocsVault AI — handles Gemini Vision calls, sync, sharing, and eligibility engine.",
    version="1.0.0",
)

# ── CORS ─────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],   # Tighten in production to exact app domain/scheme
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Custom Middleware ─────────────────────────────────────────────────────────
app.add_middleware(RateLimitMiddleware)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth.router,      prefix="/auth",      tags=["Auth"])
app.include_router(scan.router,      prefix="/scan",      tags=["Scan"])
app.include_router(assistant.router, prefix="/assistant", tags=["Assistant"])
app.include_router(sync.router,      prefix="/sync",      tags=["Sync"])
app.include_router(share.router,     prefix="/share",     tags=["Share"])


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "docsvault-ai-backend"}
