"""Shared helpers: throttled HTTP with retries, CRS transforms, JSON IO."""
from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

import requests
from pyproj import Transformer

import config

_session = requests.Session()
_session.headers["User-Agent"] = config.USER_AGENT
_last_request = 0.0


def http_get(url: str, params: dict[str, Any] | None = None, *, retries: int = 5,
             timeout: float = 300.0, method: str = "GET", data: dict[str, Any] | None = None) -> bytes:
    """GET/POST with throttling and exponential backoff. 4xx (except 429) fails immediately."""
    global _last_request
    delay = 5.0
    for attempt in range(1, retries + 1):
        wait = config.REQUEST_PAUSE_S - (time.monotonic() - _last_request)
        if wait > 0:
            time.sleep(wait)
        _last_request = time.monotonic()
        try:
            r = _session.request(method, url, params=params, data=data, timeout=timeout)
            if r.status_code == 200 and r.content:
                return r.content
            if 400 <= r.status_code < 500 and r.status_code != 429:
                raise RuntimeError(f"HTTP {r.status_code} for {url}: {r.text[:300]}")
            print(f"  HTTP {r.status_code} ({len(r.content)} B) attempt {attempt}/{retries}")
        except requests.RequestException as exc:
            print(f"  {type(exc).__name__}: {exc} attempt {attempt}/{retries}")
        time.sleep(delay)
        delay *= 2
    raise RuntimeError(f"download failed: {url}")


def overpass(query: str, require: tuple[str, ...]) -> bytes:
    """Run an Overpass query on the configured mirrors; reject partial/remark responses."""
    last: Exception | None = None
    for ep in config.OVERPASS_ENDPOINTS:
        try:
            print(f"[overpass] {ep}")
            raw = http_get(ep, method="POST", data={"data": query}, retries=3, timeout=180)
            doc = json.loads(raw)
            if doc.get("remark"):
                raise RuntimeError(f"Overpass remark: {doc['remark']}")
            kinds = {e["type"] for e in doc.get("elements", [])}
            missing = [k for k in require if k not in kinds]
            if missing:
                raise RuntimeError(f"response lacks {missing}")
            return raw
        except Exception as exc:  # try the next mirror
            last = exc
            print(f"[overpass] {ep} failed: {exc}")
    raise RuntimeError(f"all Overpass endpoints failed: {last}")


def transformer(src: str, dst: str) -> Transformer:
    return Transformer.from_crs(src, dst, always_xy=True)


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))
