# Architecture (v1)

```
Android (Flutter, local-first)
  ├─ Yahoo Finance (search/quote/history) — works offline-backend
  └─ optional HTTPS API  (device JWT)
        │
        ▼
   FastAPI (:8010)
        ├─ Postgres (books, lots, jobs, reports)
        ├─ Redis (ARQ queue)
        └─ Worker
              ├─ Local tape desk
              ├─ CLI desk (via LLM bridge → kimi/cursor)
              └─ TradingAgentsGraph.propagate(..., portfolio=PortfolioContext)
                        │
                        ▼
                 LLM bridge :8099  OR  DeepSeek/OpenAI APIs
```

## Why keys are not in the APK

TradingAgents and copilot LLMs bill per token. Device pairing + server-side env keeps spend controlled. LAN lab mode (`ALLOW_INSECURE_NOAUTH=1`) is for home Wi-Fi only.

## PortfolioContext

Tauric `tradingagents.portfolio.PortfolioContext` receives cash, currency, and positions so a BUY on a 40% name surfaces as a PM note, not a vacuum signal.

## Attribution

TradingAgents © Tauric Research, Apache-2.0.
