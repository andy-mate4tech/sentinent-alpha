# Architecture: Sentient Alpha + Tauric Research TradingAgents

For the v1 product (full backend + AI Android app, analyst / advisor / PM features), the source of truth is **[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)**. This file describes the **v0** APK and the Tauric adapter as they exist today.

This APK does **not** embed [TauricResearch/TradingAgents](https://github.com/TauricResearch/TradingAgents). That repo is a **Python LangGraph multi-agent trading firm**. It needs a Python 3.12 runtime, LLM API keys, and data vendors. Flutter/Dart cannot run it in-process on a phone.

The shipped APK is therefore a **no-login on-device tracker** that:

1. Opens straight to Track (no account, no app server).
2. Resolves a name or ticker on Yahoo Finance search.
3. Pulls last price and a daily sparkline from Yahoo chart.
4. If you enter a **buy date**, looks up that session’s close as cost.
5. If you enter a **dollar amount** that looks like a total, infers quantity.
6. Persists lots on the phone and **re-quotes about every 45 seconds**.
7. Runs a **local desk** that sits in the same seats as TradingAgents (technicals, fundamentals, sentiment, news, bull/bear, trader, risk, PM) using the Yahoo tape.

That local desk is a stand-in. To use the real Tauric firm, stand up the backend below and paste its URL in the app’s **About** tab.

TradingAgents is Apache-2.0 and **research-only**. It is not financial, investment, or trading advice. Same for this APK.

---

## Why a backend is required for the real firm

```
TradingAgentsGraph.propagate("NVDA", "2026-09-18")
```

That call:

- Builds a LangGraph with analyst, researcher, trader, risk, and PM nodes.
- Calls an LLM provider (OpenAI, Gemini, Anthropic, Grok, DeepSeek, Qwen, GLM, MiniMax, OpenRouter, Ollama, Azure, Bedrock, or any OpenAI-compatible server).
- Pulls market/news/macro data (yfinance, optional Alpha Vantage, FRED, Polymarket).
- Can run for **minutes** and cost **tokens per ticker**.
- Writes a decision log under `~/.tradingagents/memory/`.

None of that fits inside an APK without shipping Python, keys, and a GPU/LLM. Keys must stay off the device.

---

## System diagram

```
┌────────────────────────────┐
│  Sentient Alpha APK        │
│  (Flutter, no login)       │
│                            │
│  Track  → Yahoo search +   │
│           chart (public)   │
│  Monitor → 45s re-quote    │
│  Copilot → book + last desk│
│  Desk    → local seats     │
│            OR HTTP POST    │
└─────────────┬──────────────┘
              │  POST /v1/desk/analyze
              │  { ticker, trade_date, avg_cost, shares }
              ▼
┌────────────────────────────┐
│  tauric_backend (FastAPI)  │  ← this repo, sentient_alpha/tauric_backend
│  thread pool, 1 job/ticker │
└─────────────┬──────────────┘
              │  TradingAgentsGraph.propagate(ticker, date)
              ▼
┌────────────────────────────┐
│  TauricResearch/           │
│  TradingAgents             │
│                            │
│  Analysts → Bull/Bear →    │
│  Trader → Risk → PM        │
│                            │
│  LLM keys  +  yfinance     │
└────────────────────────────┘
```

**Default path (this APK, zero servers):** Yahoo + local desk.  
**Optional path:** set backend URL in About. Desk calls Tauric; if the host is down it falls back to local.

---

## On-device data plane (no Tauric)

| Step | Source | Used for |
| --- | --- | --- |
| Search | `https://query1.finance.yahoo.com/v1/finance/search` | Name → ticker |
| Quote / sparkline | `https://query1.finance.yahoo.com/v8/finance/chart/{TICKER}` | Last, change, 6m window |
| Cost on a date | same chart API with `period1` / `period2` | Historical close as avg cost |
| News headlines | Yahoo search `newsCount` | Local news analyst |
| Lots | `shared_preferences` | Survive process death |

Quantity is **not** in Yahoo. The app infers it only when the cash figure is much larger than last/historical price (treat as total dollars). Otherwise quantity defaults to 1 until you type shares.

Monitor alerts:

- Move ≥ 3% since last check.
- Price crosses your cost basis.

---

## HTTP contract (when you attach Tauric)

`POST {baseUrl}/v1/desk/analyze`

```json
{
  "ticker": "NVDA",
  "trade_date": "2026-09-18",
  "avg_cost": 118.4,
  "shares": 10
}
```

`trade_date` may be omitted (server uses UTC today). `avg_cost` / `shares` are optional context for your own logging; TradingAgents itself keys off ticker + date.

**200 response** (the APK maps any of these fields):

```json
{
  "ticker": "NVDA",
  "trade_date": "2026-09-18",
  "decision": "BUY",
  "score": 72,
  "market_report": "...",
  "fundamentals_report": "...",
  "sentiment_report": "...",
  "news_report": "...",
  "bull_history": "...",
  "bear_history": "...",
  "trader_investment_plan": "...",
  "final_trade_decision": "..."
}
```

Timeouts: the app waits **180s**. TradingAgents often needs that. Run one ticker at a time.

Use `http://` on a LAN (the APK allows cleartext) or `https://` behind a reverse proxy. Do **not** put LLM keys in the APK.

---

## Stand up the real desk

From a machine that can reach the phone (same Wi-Fi, or a VPS):

```bash
git clone https://github.com/TauricResearch/TradingAgents.git
cd TradingAgents
python3.12 -m venv .venv
source .venv/bin/activate
pip install .
pip install fastapi uvicorn

export OPENAI_API_KEY=sk-...          # or GOOGLE_API_KEY / ANTHROPIC_API_KEY / Ollama
# optional:
export ALPHA_VANTAGE_API_KEY=...
export FRED_API_KEY=...

# copy the thin API from this project
#   sentient_alpha/tauric_backend/app.py
uvicorn app:app --host 0.0.0.0 --port 8000
```

Ollama (no cloud key):

```bash
export TRADINGAGENTS_LLM_PROVIDER=ollama
export TRADINGAGENTS_DEEP_THINK_LLM=llama3.1
export TRADINGAGENTS_QUICK_THINK_LLM=llama3.1
ollama pull llama3.1
```

Tauric’s own Docker:

```bash
cd TradingAgents
cp .env.example .env   # fill keys
docker compose run --rm tradingagents
```

That image is the **CLI**. The FastAPI wrapper in `sentient_alpha/tauric_backend` is what the APK calls. You can install TradingAgents inside that container or `pip install -e /path/to/TradingAgents` next to `app.py`.

Phone configuration:

1. About tab → backend URL `http://192.168.x.x:8000`
2. Track a ticker
3. Desk → Run desk → source badge becomes **Tauric TradingAgents**

---

## Agent mapping

| Tauric seat | On-device stand-in | Real backend |
| --- | --- | --- |
| Technical analyst | RSI14, SMA20, window return, range, daily vol from Yahoo closes | LangGraph market/technical node + yfinance indicators |
| Fundamentals analyst | Name, exchange, 6m high/low (no 10-K) | Fundamentals tools (yfinance / Alpha Vantage) |
| Sentiment analyst | Session % and range percentile | StockTwits / Reddit grounded sentiment |
| News analyst | Yahoo search headlines | Ticker + global news vendors |
| Bull / bear researchers | Tape arguments | Debate rounds (`max_debate_rounds`) |
| Trader | Local rating + hold/trim language | `trader_investment_plan` |
| Risk | Notional 10% shock, window vol | Aggressive / conservative / neutral debate |
| Portfolio manager | 5-tier rating from local score | `final_trade_decision` + memory log |

Python entry (from Tauric’s README):

```python
from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG

ta = TradingAgentsGraph(debug=False, config=DEFAULT_CONFIG.copy())
state, decision = ta.propagate("NVDA", "2026-09-18")
```

---

## Sequence (add a lot, then real desk)

```
User                 APK                    Yahoo              Tauric API
 │                    │                       │                     │
 │  NVDA, date, $     │                       │                     │
 │───────────────────▶│  search / chart       │                     │
 │                    │──────────────────────▶│                     │
 │                    │  last + hist close    │                     │
 │                    │◀──────────────────────│                     │
 │  lot saved locally │                       │                     │
 │                    │  POST /v1/desk/analyze│                     │
 │                    │────────────────────────────────────────────▶│
 │                    │                       │   propagate()       │
 │                    │  reports + decision   │                     │
 │                    │◀────────────────────────────────────────────│
 │  Desk tab renders  │                       │                     │
 │  45s later: chart refresh (Yahoo only; Tauric is on demand)      │
```

Re-running Tauric on every 45s tick would burn tokens. The APK **monitors prices** continuously and **runs the firm only when you tap Run desk** (and once when a lot is first added, local unless a URL is set).

---

## Security and ops

- LLM keys live only on the backend host (env / `.env`).
- Bind FastAPI to LAN or put it behind auth if exposed to the internet (this sample is open).
- Yahoo public endpoints can 429; the client tries query1 then query2.
- TradingAgents writes `~/.tradingagents/` (memory log, optional checkpoints). Back that up if you care about reflections.
- Research disclaimer must stay on any UI that shows a rating.

---

## What this APK will never do

- Brokerage login, order routing, or custody.
- On-device LangGraph.
- Knowing your true fill or share count without you typing it (or a total that implies it).
