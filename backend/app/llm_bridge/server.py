"""OpenAI-compatible chat completions proxy for TradingAgents / copilot.

Modes:
- cli: shell out to kimi-cli or cursor-agent
- deepseek: forward to api.deepseek.com
- openai: forward to api.openai.com
"""

from __future__ import annotations

import time
import uuid
from typing import Any

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.core.config import get_settings
from app.llm_bridge.cli_llm import complete_text

app = FastAPI(title="Sentient Alpha LLM Bridge", version="1.0.0")


class ChatMessage(BaseModel):
    role: str
    content: str | list[Any] | None = ""


class ChatRequest(BaseModel):
    model: str = "kimi-cli"
    messages: list[ChatMessage] = Field(default_factory=list)
    temperature: float | None = None
    max_tokens: int | None = None
    stream: bool | None = False


def _flatten_content(content: str | list[Any] | None) -> str:
    if content is None:
        return ""
    if isinstance(content, str):
        return content
    parts = []
    for block in content:
        if isinstance(block, dict) and block.get("type") == "text":
            parts.append(str(block.get("text") or ""))
        else:
            parts.append(str(block))
    return "\n".join(parts)


def _messages_to_prompt(messages: list[ChatMessage]) -> tuple[str | None, str]:
    system_parts = []
    user_parts = []
    for m in messages:
        text = _flatten_content(m.content)
        if m.role == "system":
            system_parts.append(text)
        else:
            user_parts.append(f"{m.role.upper()}: {text}")
    system = "\n".join(system_parts) if system_parts else None
    prompt = "\n\n".join(user_parts) if user_parts else "Hello"
    return system, prompt


@app.get("/health")
async def health():
    return {"ok": True, "service": "llm-bridge"}


@app.post("/v1/chat/completions")
async def chat_completions(body: ChatRequest):
    if body.stream:
        raise HTTPException(status_code=400, detail="streaming_not_supported")
    settings = get_settings()
    system, prompt = _messages_to_prompt(body.messages)

    if settings.llm_mode == "deepseek" and settings.deepseek_api_key:
        return await _forward_openai_compatible(
            "https://api.deepseek.com/v1/chat/completions",
            settings.deepseek_api_key,
            body,
            default_model="deepseek-chat",
        )
    if settings.llm_mode == "openai" and settings.openai_api_key:
        return await _forward_openai_compatible(
            "https://api.openai.com/v1/chat/completions",
            settings.openai_api_key,
            body,
            default_model=body.model or "gpt-4o-mini",
        )

    # CLI path
    text = await complete_text(prompt, provider=settings.llm_cli_provider, system=system)
    return {
        "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
        "object": "chat.completion",
        "created": int(time.time()),
        "model": body.model or f"{settings.llm_cli_provider}-cli",
        "choices": [
            {
                "index": 0,
                "message": {"role": "assistant", "content": text},
                "finish_reason": "stop",
            }
        ],
        "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
    }


async def _forward_openai_compatible(url: str, api_key: str, body: ChatRequest, default_model: str):
    payload = {
        "model": body.model if body.model and "cli" not in body.model else default_model,
        "messages": [{"role": m.role, "content": _flatten_content(m.content)} for m in body.messages],
    }
    if body.temperature is not None:
        payload["temperature"] = body.temperature
    if body.max_tokens is not None:
        payload["max_tokens"] = body.max_tokens
    async with httpx.AsyncClient(timeout=180.0) as client:
        r = await client.post(
            url,
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json=payload,
        )
        if r.status_code >= 400:
            raise HTTPException(status_code=r.status_code, detail=r.text[:500])
        return r.json()


# Also expose at root for clients that omit /v1
@app.post("/chat/completions")
async def chat_completions_root(body: ChatRequest):
    return await chat_completions(body)
