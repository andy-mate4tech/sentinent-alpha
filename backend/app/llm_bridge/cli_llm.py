"""LLM completion: host CLI binaries, or OpenAI-compatible LLM bridge URL."""

from __future__ import annotations

import asyncio
import os
import shutil
from typing import Literal

import httpx

from app.core.config import get_settings
from app.core.logging import get_logger

log = get_logger("llm.cli")

Provider = Literal["kimi", "cursor"]


def _which_kimi() -> str | None:
    for cand in (
        shutil.which("kimi"),
        shutil.which("kimi-code"),
        "/root/.local/bin/kimi-code",
        "/usr/local/bin/kimi",
        "/host/bin/kimi-code",
        "/host/bin/kimi",
    ):
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def _which_cursor() -> str | None:
    for cand in (
        shutil.which("cursor-agent"),
        shutil.which("agent"),
        "/root/.local/bin/cursor-agent",
        "/root/.local/bin/cursor",
        "/host/bin/cursor-agent",
        "/host/bin/cursor",
    ):
        if cand and os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


async def complete_text(
    prompt: str,
    *,
    provider: Provider = "kimi",
    system: str | None = None,
    timeout: float = 180.0,
) -> str:
    settings = get_settings()

    # Prefer DeepSeek / OpenAI direct when keyed
    if settings.llm_mode == "deepseek" and settings.deepseek_api_key:
        return await _openai_compatible(
            "https://api.deepseek.com/v1/chat/completions",
            settings.deepseek_api_key,
            prompt,
            system=system,
            model="deepseek-chat",
            timeout=timeout,
        )
    if settings.llm_mode == "openai" and settings.openai_api_key:
        return await _openai_compatible(
            "https://api.openai.com/v1/chat/completions",
            settings.openai_api_key,
            prompt,
            system=system,
            model="gpt-4o-mini",
            timeout=timeout,
        )

    # Inside Docker: call host LLM bridge (kimi/cursor on host)
    if not _which_kimi() and not _which_cursor():
        bridge = settings.llm_bridge_url.rstrip("/")
        if not bridge.endswith("/v1"):
            # accept either .../v1 or base
            url = f"{bridge}/chat/completions" if bridge.endswith("/v1") else f"{bridge}/v1/chat/completions"
        else:
            url = f"{bridge}/chat/completions"
        return await _openai_compatible(
            url,
            settings.llm_bridge_api_key,
            prompt,
            system=system,
            model=f"{provider}-cli",
            timeout=timeout,
        )

    full = f"{system}\n\n{prompt}" if system else prompt
    if provider == "cursor":
        return await _run_cursor(full, timeout=timeout)
    return await _run_kimi(full, timeout=timeout)


async def _openai_compatible(
    url: str,
    api_key: str,
    prompt: str,
    *,
    system: str | None,
    model: str,
    timeout: float,
) -> str:
    messages = []
    if system:
        messages.append({"role": "system", "content": system})
    messages.append({"role": "user", "content": prompt})
    async with httpx.AsyncClient(timeout=timeout) as client:
        r = await client.post(
            url,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json={"model": model, "messages": messages},
        )
        if r.status_code >= 400:
            raise RuntimeError(f"llm_http_{r.status_code}:{r.text[:300]}")
        data = r.json()
        return data["choices"][0]["message"]["content"]


async def _run_kimi(prompt: str, timeout: float) -> str:
    exe = _which_kimi()
    if not exe:
        raise RuntimeError("kimi_cli_not_found")
    cmd = [exe, "--quiet", "-y", "-p", prompt]
    log.info("kimi_invoke", exe=exe)
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError as exc:
        proc.kill()
        raise RuntimeError("kimi_timeout") from exc
    if proc.returncode != 0:
        err = (stderr or b"").decode("utf-8", errors="replace")[:500]
        raise RuntimeError(f"kimi_failed:{err}")
    return (stdout or b"").decode("utf-8", errors="replace").strip()


async def _run_cursor(prompt: str, timeout: float) -> str:
    exe = _which_cursor()
    if not exe:
        raise RuntimeError("cursor_cli_not_found")
    cmd = [exe, "-p", "--force", prompt]
    log.info("cursor_invoke", exe=exe)
    proc = await asyncio.create_subprocess_exec(
        *cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    try:
        stdout, stderr = await asyncio.wait_for(proc.communicate(), timeout=timeout)
    except asyncio.TimeoutError as exc:
        proc.kill()
        raise RuntimeError("cursor_timeout") from exc
    text = (stdout or b"").decode("utf-8", errors="replace").strip()
    if not text:
        text = (stderr or b"").decode("utf-8", errors="replace").strip()
    if proc.returncode != 0 and not text:
        raise RuntimeError("cursor_failed")
    return text
