"""Limitador básico por IP para una sola instancia.

En despliegues con varias réplicas debe complementarse con límites en el proxy,
WAF o API Gateway.
"""

from __future__ import annotations

import asyncio
import time
from collections import defaultdict, deque
from typing import Deque, Dict, Tuple

from fastapi import Request
from fastapi.responses import JSONResponse


RULES: Dict[Tuple[str, str], Tuple[int, int]] = {
    ("POST", "/api/admin/login"): (5, 300),
    ("POST", "/api/admin/refresh"): (20, 300),
    ("POST", "/api/admin/change-password"): (5, 900),
    ("POST", "/api/reportes/analizar-previa"): (12, 60),
    ("POST", "/api/reportes"): (10, 3600),
    ("POST", "/api/suggestions"): (10, 3600),
    ("GET", "/api/reportes/consulta"): (30, 300),
}


class RateLimiter:
    def __init__(self) -> None:
        self._events: Dict[str, Deque[float]] = defaultdict(deque)
        self._lock = asyncio.Lock()

    async def middleware(self, request: Request, call_next):
        rule = RULES.get((request.method.upper(), request.url.path))
        if not rule:
            return await call_next(request)

        limit, window = rule
        client_ip = request.client.host if request.client else "unknown"
        key = f"{client_ip}:{request.method.upper()}:{request.url.path}"
        now = time.monotonic()

        async with self._lock:
            events = self._events[key]
            while events and now - events[0] >= window:
                events.popleft()
            if len(events) >= limit:
                retry_after = max(1, int(window - (now - events[0])))
                return JSONResponse(
                    status_code=429,
                    content={"detail": "Demasiadas solicitudes. Intente nuevamente más tarde."},
                    headers={"Retry-After": str(retry_after)},
                )
            events.append(now)

        return await call_next(request)


rate_limiter = RateLimiter()
