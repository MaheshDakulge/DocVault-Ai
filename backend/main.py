"""
DigiSafe AI – FastAPI Backend Entry Point
=========================================
Bootstraps the application, registers all API routers, configures
CORS middleware, and exposes root health-check endpoints.
"""

from contextlib import asynccontextmanager

import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.auth import router as auth_router
from app.api.documents import router as documents_router
from app.api.scan import router as scan_router
from app.api.search import router as search_router
from app.api.assistant import router as assistant_router
from app.api.share import router as share_router


# ── Lifespan (startup / shutdown) ────────────────────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Application lifespan handler (replaces deprecated @app.on_event).

    Startup logic runs before ``yield``; shutdown logic runs after.
    """
    # ── Startup ──────────────────────────────────────────────────────────
    print("[START] DigiSafe AI backend starting up...")
    # TODO: initialise DB connection pool, ML models, caches, etc.

    yield  # ← application is live and serving requests here

    # ── Shutdown ─────────────────────────────────────────────────────────
    print("[STOP] DigiSafe AI backend shutting down...")
    # TODO: close DB connections, flush caches, cancel background tasks, etc.


# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="DigiSafe AI",
    version="1.0.0",
    description=(
        "Backend for DigiSafe AI — secure document scanning, "
        "AI-powered extraction, and intelligent search."
    ),
    lifespan=lifespan,
)

# ── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],        # Restrict to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(auth_router,      prefix="/auth",      tags=["auth"])
app.include_router(documents_router, prefix="/documents", tags=["documents"])
app.include_router(scan_router,      prefix="/scan",      tags=["scan"])
app.include_router(search_router,    prefix="/search",    tags=["search"])
app.include_router(assistant_router, prefix="/assistant", tags=["assistant"])
app.include_router(share_router,     prefix="/share",     tags=["share"])


# ── Health endpoints ──────────────────────────────────────────────────────────
@app.get("/", tags=["health"])
async def root() -> dict:
    """Liveness probe – confirms the API is reachable."""
    return {"status": "ok", "app": "DigiSafe AI", "version": "1.0.0"}


@app.get("/health", tags=["health"])
async def health_check() -> dict:
    """
    Readiness probe.

    Extend this to perform real DB/service checks and return HTTP 503
    when a dependency is unavailable.
    """
    return {"status": "healthy", "database": "connected"}


# ── Entry point ───────────────────────────────────────────────────────────────
if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info",
    )
