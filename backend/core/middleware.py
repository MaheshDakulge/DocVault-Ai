import time
from collections import defaultdict
from typing import Callable
from fastapi import Request, Response
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware


class RateLimitMiddleware(BaseHTTPMiddleware):
    """
    Simple in-memory rate limiter.
    Limits: 30 req/min for /scan, 60 req/min for all others.
    In production, replace with Redis-backed limiter.
    """

    def __init__(self, app, scan_limit: int = 30, global_limit: int = 60):
        super().__init__(app)
        self._scan_limit = scan_limit
        self._global_limit = global_limit
        self._requests: dict[str, list[float]] = defaultdict(list)

    async def dispatch(self, request: Request, call_next: Callable) -> Response:
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        window = 60.0  # 1-minute window

        key = f"{client_ip}:{request.url.path}"
        # Clean old timestamps
        self._requests[key] = [t for t in self._requests[key] if now - t < window]

        limit = self._scan_limit if "/scan" in request.url.path else self._global_limit
        if len(self._requests[key]) >= limit:
            return JSONResponse(
                status_code=429,
                content={"detail": f"Rate limit exceeded. Max {limit} requests/min."},
            )

        self._requests[key].append(now)
        return await call_next(request)
