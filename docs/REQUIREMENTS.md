# Sentient Alpha — Cursor Agent Requirements

**Document type:** Product + engineering specification for a Cursor (or similar) coding agent.
**Product:** Sentient Alpha — personal AI research terminal for people who hold stocks, ETFs, and crypto.
**Target repo:** https://github.com/andy-mate4tech/sentinent-alpha
**Status:** v1.0 spec. Build from scratch. Treat the current Flutter demo as **reference only**, not the finished product.
**Audience:** A coding agent implementing the complete Android app **and** backend without further product questions.

If a choice is ambiguous, use the **Recommended default** in §22. Do not stop to ask. Do not invent brokerage, custody, or live order routing.

---

## 0. How a Cursor agent must use this file

1. Read this document end to end before writing code.
2. Read `ARCHITECTURE.md` and `lib/` in this folder only as **v0 reference** (Yahoo lookup, lot inference, Tauric seat names, dark UI).
3. Build a **greenfield monorepo** (layout in §20). Do not grow the current single-file `lib/main.dart` demo into v1 by accretion.
4. Deliver in **phases P0 → P1 → P2**. P0 must be installable (APK + docker-compose backend) before P1 cosmetics.
5. Every screen that shows a rating, score, or “add / trim / hold” sentence must show the research disclaimer in §4.
6. **Do not delete** the sibling Gmail Agent project if this workspace still contains it. Sentient Alpha and Gmail Agent are separate apps.
7. **Do not put LLM API keys in the APK.** Keys live in backend env.
8. TradingAgents is Apache-2.0, **research-only**. Preserve attribution. Do not claim returns.
9. Tests are part of the work: backend pytest + Flutter widget/unit tests for money math. A feature without tests is not done.
10. Ship an Android **release APK** and a GitHub Actions workflow that publishes it on `v*` tags as `sentient-alpha.apk`.

---

## 1. Product thesis

Sentient Alpha is the phone a thoughtful individual investor actually uses: **add what you bought in one step**, see whether you are making or losing money, understand **why**, and get a **portfolio manager’s view of the whole book** — concentration, risk, goals, and a debate-style research desk — without opening a broker and without pretending the app is a registered adviser.

The original user request, preserved:

> Open the app (no sign-in). Enter a stock **name or id**, plus **cost** or **buy date**. The system looks up cost/quantity, then **keeps monitoring**. Use Tauric Research’s trading-house (TradingAgents) for the AI desk. If that needs a backend, provide the complete architecture.

v1 keeps that one-step capture as the **front door**, then adds the work a real **equity analyst**, **financial advisor**, and **portfolio manager** would refuse to skip (allocation, lots, risk, goals, thesis, calendar, tax holding period, scenarios, a grounded copilot).

**Positioning line (UI subtitle):** `RESEARCH TERMINAL · NOT ADVICE`

**What it is not:** a broker, a hedge fund, a robo-adviser with discretion, or a signal service that auto-trades.

---

## 2. Captured requirements (from the product owner)

These are non-negotiable. If a later section conflicts, this section wins.

| ID | Requirement |
| --- | --- |
| U1 | Android app, Flutter. Dark “terminal” visual language (canvas `#0B0F19`, mint `#10B981`, cyan `#38BDF8`, coral `#F43F5E`, Plus Jakarta Sans + JetBrains Mono). |
| U2 | First launch works **without an account** and **without a reachable backend**. Quotes still resolve. |
| U3 | Add a position with: **name or ticker**, optional **quantity**, **cost** (per share **or** total dollars), and/or **buy date**. |
| U4 | Resolve identity and last price via **Yahoo Finance** public search + chart APIs (US, India `.NS`/`.BO`, Japan `.T`, HK `.HK`, UK `.L`, Canada `.TO`, Australia `.AX`, China `.SS`/`.SZ`, crypto `BTC-USD` / `ETH-USD`). |
| U5 | If buy date is given, **look up that session’s close** as cost basis. |
| U6 | If the user types a cash figure much larger than price, **infer share count**. Quantity is never in Yahoo; never invent a fill. |
| U7 | Persist lots on device; **re-quote on a ~45s cadence** while the app is open; alert on ≥3% move since last check and on **cost-basis cross**. |
| U8 | AI desk sits in Tauric Research TradingAgents **seats**: Technical, Fundamentals, Sentiment, News, Bull, Bear, Research Manager, Trader, Aggressive/Neutral/Conservative Risk, Portfolio Manager. |
| U9 | Real TradingAgents is Python + LangGraph + LLM keys. It **cannot run in-process in Flutter**. Backend adapter is required. On-device desk is a **fallback** using the Yahoo tape when the backend is absent or down. |
| U10 | Optional backend URL in settings (LAN `http://` allowed for debug). Production backend uses HTTPS. |
| U11 | Copilot answers in plain language about **this user’s book** (P/L, last desk, how Tauric is wired). |
| U12 | No Gmail Agent features inside this app. Do not remove Gmail Agent from a shared workspace. |
| U13 | Research / informational only. Not financial, investment, or trading advice. Same disclaimer as Tauric. |
| U14 | GitHub repo `andy-mate4tech/sentinent-alpha`; APK published on Releases as `sentient-alpha.apk`. |
| U15 | No live brokerage login, order routing, or custody in this version. |

v0 already implements U1–U14 at demo quality. v1 must implement them **and** §3.

---

## 3. Gap analysis — think like the three seats

The v0 demo is a **quote + single-lot + local score** toy. A professional would not manage money with it. This section is the missing product.

### 3.1 Equity / research analyst

What they do that v0 does not:

- Separate **watchlist** (ideas) from **holdings** (capital at risk).
- Full tape: OHLC, volume, 52-week range, pre/post market when Yahoo has it, not only last + 6m sparkline.
- Technicals a human actually uses: SMA 20/50/200, RSI14, MACD, ATR, average volume, distance from 52w high, relative strength vs sector ETF and vs regional benchmark (`SPY`, `^NSEI`, `^N225`, `^HSI`, etc.).
- Fundamentals snapshot: market cap, P/E, PEG, EV/EBITDA, revenue and EPS growth, gross/operating/FCF margin, ROE, ROIC, debt/equity, current ratio, short interest if available, dividend yield and payout. Prefer **point-in-time** vendors (SEC EDGAR via TradingAgents for US filers).
- **Peers** (3–6 names) on the same multiples and 6m return.
- **Catalyst calendar:** earnings date, ex-dividend, known macro prints the news agent cares about.
- **Investment thesis** on each holding: “why I own this”, **invalidation** (“sell/review if …”), and a link to the last desk report.
- News with **source, time, URL** — not anonymous strings. Mark opinion vs filing.
- Insider / 13F only if a vendor is configured; otherwise omit rather than fabricate.
- Explicit **data-as-of** timestamps on every number.

### 3.2 Financial advisor (planning, suitability, behaviour)

What they do that v0 does not:

- Know the **household goal**, not only the ticker: retirement, house, education, “do not lose this emergency cash”.
- **Risk tolerance + time horizon** (short questionnaire → a suggested strategic allocation). The app may **suggest**; it must not **allocate with discretion**.
- **Emergency fund vs invested capital.** Flag if the book looks like it is the user’s rent money (user-stated cash-need date).
- **Contributions / SIP / DCA log** so “I put in 500 a month” is first-class, not a fake return.
- **Holding period:** short-term vs long-term lot aging (default convention: US 365-day long-term; show as “tax hint, not a filing”).
- **Suitability flags:** crypto, single-name > X% of book, leverage/inverse ETFs, 3x products. Explain in one sentence why it is flagged.
- **Behavioural coaching:** do not nag; do surface “you are adding to a name that is already 28% of equity” before they save the lot.
- **Plain-language explainer** on every desk rating (“Hold means: the desk does not see a clear edge after costs and risk”).
- **Weekly review ritual:** one screen, Sunday-style: what moved, what is crowded, what is coming (earnings), what drifted from target.
- Export for a human adviser: CSV of lots + PDF/HTML one-pager of allocation and risk (P2).

### 3.3 Portfolio manager (the book, not the name)

What they do that v0 does not:

- **Cash** is a position. A book without cash is incomplete.
- **Multiple lots** per ticker (buys on different dates). Average cost **and** FIFO lot view. Sells realize P/L against lots; do not just delete the ticker.
- **Corporate actions:** split/reverse-split adjust shares and cost. If Yahoo chart is split-adjusted (it is), store **split-adjusted** cost and show a note. Cash dividends logged as transactions (income), not silent NAV magic.
- **Base currency** (user setting, default USD) with FX conversion for `RELIANCE.NS`, `7203.T`, `0700.HK`, `BTC-USD`.
- **Allocation:** by asset class, sector, geography, and single-name. Target weights optional. Drift vs target.
- **Concentration:** HHI, top-5 weight, largest name, largest sector. Hard warn ≥25% one name (configurable).
- **Risk:** weighted beta vs benchmark, 30/90/365d volatility, max drawdown of the **book** (from stored daily NAV, not from a single sparkline), simple historical 95% 1-day loss. Sharpe/Sortino vs 0 or vs T-bill only if a risk-free series is available (FRED); otherwise omit the ratio rather than fake r_f.
- **Correlation:** pairwise 90d return correlation of holdings; flag two names >0.85 as “not diversifying each other”.
- **Scenarios (no Monte Carlo theatre in P0):** book P/L if each name −10%; if the largest name −30%; if beta-1 factor −10%. Show dollar impact.
- **Liquidity:** 20d average dollar volume; warn if position > 5% of ADV (cannot exit cleanly).
- **Benchmark:** user-picked (`SPY`, `QQQ`, `VTI`, `^NSEI`, custom). Book vs benchmark on 1m/3m/6m/YTD/1y when history exists.
- **Paper decision journal:** each Tauric run stored with rating, score, portfolio weights at the time; later mark “what happened 5/21/63 days later”. This is how Tauric’s own memory log is meant to be used.
- **Portfolio-aware desk:** TradingAgents v0.5+ accepts `PortfolioContext` (cash, currency, positions). The backend **must pass the user’s actual book**, not a nameless ticker. A “BUY” on a name that is already 40% of equity must come back as a PM note, not a vacuum signal.

### 3.4 Product / engineering gaps in v0

- Copilot is **canned string matching**, not an LLM with tools.
- Desk is **synchronous 180s HTTP** — will die on mobile networks. Need **async jobs + progress**.
- No quote cache, so Yahoo **429**s.
- One lot per ticker (add replaces).
- No push notifications, no background fetch.
- No user profile, no backup except `shared_preferences`.
- Backend is an unauthenticated open proxy to an LLM bill.
- No NAV history, so no real drawdown.
- No tests for FX, lots, or realized P/L.

---

## 4. Legal, safety, non-goals

### 4.1 Disclaimer (verbatim on first launch, About, Desk, Copilot, and any share/export)

> Sentient Alpha is a research and bookkeeping tool. Ratings, scores, scenarios, and copilot text are informational and may be wrong. They are **not** financial, investment, tax, or trading advice, and not an offer to buy or sell any security. TradingAgents is a research framework; past or simulated results do not predict future results. You can lose money. You are responsible for your own decisions. If you need advice, consult a licensed professional in your jurisdiction.

### 4.2 Hard non-goals (do not build)

- Brokerage OAuth, order tickets, smart routing, options chains trading, futures, margin borrowing.
- “Auto-trade when the desk says BUY.”
- Guaranteed returns, win-rate marketing, or backtest numbers presented as live performance of this app.
- Storing the user’s broker password.
- Silent emails/SMS to third parties.
- Medical, legal, or tax filing.
- Replacing Gmail Agent or merging the two codebases.
- Running LangGraph inside the APK.
- Scraping paywalled research and republishing it.

### 4.3 Soft non-goals (not P0–P1)

- iOS (architecture should not block it; do not spend P0 on it).
- Multi-user household adviser portal.
- Social feed / copy-trading.
- On-chain wallet connect.

---

## 5. Personas and jobs-to-be-done

| Persona | Job | Success |
| --- | --- | --- |
| **Owner (primary)** | “I bought RELIANCE in 2023, I forget the exact fill, I want to know if I am ok.” | 30 seconds: name + date or cost → live P/L + monitoring. |
| **Analyst-minded user** | “Is the story intact before earnings?” | Thesis, calendar, desk seats, peers, as-of stamps. |
| **Advisor-minded user** | “Is this book too concentrated for a 7-year house goal?” | Goals, allocation vs target, suitability flags, weekly review. |
| **PM-minded user** | “If NVDA drops 30%, what happens to me, and should the desk still say overweight?” | Lots, cash, scenarios, portfolio-aware Tauric, journal. |

Primary device: Android phone, often mid-range, often India/US. Network: flaky. Backend may be a laptop on the same Wi-Fi or a small VPS.

---

## 6. Experience principles

1. **Capture is sacred.** Track tab stays one screen: search, optional qty, cost, date, primary CTA `Track with AI desk`.
2. **Money is never ambiguous.** Always show currency, as-of time, and whether P/L is unrealized or realized. Use `+`/`−` and color, but never color alone (pair with sign).
3. **Local-first.** Killing the backend does not wipe the book or freeze last quotes. Stale quotes get a `STALE` pill after 5 minutes.
4. **One active expensive job.** Tauric runs are slow and costly. Queue per ticker; show progress; never fire Tauric on the 45s refresh.
5. **Ground the model.** Copilot may only cite quotes, lots, desk reports, calendars, and analytics the tools returned. If a tool fails, say so.
6. **Explain then rate.** Desk UI shows seat reports first, rating last, so the number is not the product.
7. **Warn before concentrate.** Confirm dialog if the new lot would push a name over the concentration cap.
8. **Numbers beat adjectives.** “12.4% of book, 0.82 corr with QQQ” not “somewhat tech-heavy”.
9. **Empty states teach the next action.** No lorem, no dummy brokerage login.
10. **Accessibility:** 44dp targets, dynamic type up to 1.3× without clipping P/L, not mint-on-cyan text.

---

## 7. Information architecture (Android)

Bottom navigation (5 destinations — v0 had 4; **Book** is new and required):

| Tab | Purpose |
| --- | --- |
| **Track** | Add/edit lots and watchlist; live marks; alerts strip. |
| **Book** | Portfolio PM view: NAV, allocation, risk, goals, scenarios. |
| **Desk** | Tauric seats for a selected ticker or for “whole book”. |
| **Copilot** | Grounded chat with tools. |
| **More** | Settings, backend, disclaimer, export, about. |

### 7.1 Screen inventory

**Track**

- Header: NAV (base ccy), day change, desk/backend pill (`LOCAL` / `CLOUD` / `JOB RUNNING`), last quote time.
- Search field with live Yahoo hits (type, exchange, quoteType).
- Fields: quantity, cost, buy date, optional note/thesis (one line).
- CTA: `Track with AI desk`.
- List of holdings (ticker, qty, avg cost, mark, uPnL $, uPnL %, weight).
- Watchlist section (no qty).
- Alerts (last 20), tappable to the name.
- Pull-to-refresh.

**Lot detail** (push from Track)

- Chart (1m/3m/6m/1y/5y).
- Lots table (date, qty, cost, holding period days, short/long hint).
- Edit qty/cost, add lot, record sell, record dividend.
- Thesis + invalidation.
- Last desk rating + `Run desk`.
- Fundamentals snapshot + peers.
- Calendar (earnings, ex-div if known).
- Suitability flags.

**Book**

- NAV, cost, uPnL, realized (period toggle: today / MTD / YTD / inception).
- Cash line + `Add cash` / `Spend cash` (manual).
- Allocation donuts: asset class, sector, region, top names.
- Target vs actual (if targets set).
- Risk strip: beta, 90d vol, max DD, HHI, top name %.
- Scenario cards.
- Benchmark overlay (sparkline NAV vs benchmark, rebased 100).
- Goals progress.
- `Weekly review` button → generated brief (cached 12h).

**Desk**

- Ticker picker (holdings + watchlist).
- `Run desk` / `Run book review` (portfolio-aware).
- Job progress (analysts → researchers → trader → risk → PM).
- Seat accordion with source badge (`Tauric` vs `Local tape`).
- Five-tier rating + score.
- Compare to previous run (rating change).
- Disclaimer.

**Copilot**

- Thread, persisted on device (and cloud if signed in).
- Suggested chips: `How is my book?`, `What moved today?`, `Am I too concentrated?`, `Explain the last NVDA desk`, `What if NVDA −30%?`.
- Citations under each assistant turn (ticker, field, as-of).
- `Reset thread` does not delete lots.

**More / Settings**

- Backend base URL + `Test connection`.
- Optional account: magic link or Google (for sync only).
- Base currency, benchmark ticker, concentration cap, quote refresh interval (15/30/45/60s).
- Risk questionnaire (advisor).
- Notification categories.
- Export CSV / backup JSON / restore.
- Disclaimer + licences (Flutter, TradingAgents Apache-2.0, Yahoo usage note).
- LLM copilot: Off / On-device Gemini Nano if present / Backend.

**Onboarding (first launch, 3 screens max)**

1. Disclaimer accept.
2. Base currency + optional risk questions (skippable).
3. “Add your first lot” → Track.

No dummy login. No markets-discovery theatre.

---

## 8. Feature catalog (MoSCoW)

### P0 — Must (greenfield vertical slice)

- U1–U15 from §2.
- Monorepo: Flutter app + FastAPI backend + worker + docker-compose.
- Device persistence (SQLCipher or drift + encrypted prefs for secrets).
- Yahoo search, quote, historical close, news, 52w, currency of the instrument.
- Position inference algorithm **exactly** as v0 `inferPosition` (keep behaviour; add tests).
- Multiple lots per ticker (adding the same ticker **adds a lot**, does not replace, unless user confirms merge).
- Cash balance (default 0, user-editable).
- 45s monitor + in-app alerts (≥3% move, cost cross).
- Local desk fallback (same seats, Yahoo tape) + HTTP desk job API.
- Async Tauric job: `POST /v1/jobs/desk` → poll `GET /v1/jobs/{id}` (or WebSocket). Timeout 10 minutes. One running Tauric job per user/device.
- Pass `PortfolioContext` into `TradingAgentsGraph.propagate` when holdings exist.
- Health endpoint, structured logs, no secrets in logs.
- Disclaimer, About, backend URL field.
- Flutter tests for inference, P/L, concentration warning; pytest for job API with a fake graph.
- Release APK workflow.

### P1 — Should (professional book)

- Book tab: weights, sector/geo (Yahoo quoteProfile / assetProfile when present; otherwise `Unknown` — never invent GICS).
- Base currency FX (Yahoo `USDCNY=X`, `USDINR=X`, etc.). Convert NAV to base.
- Concentration cap warning (default 25%).
- Watchlist.
- Push notifications (FCM) for: cost cross, ≥5% day move (user threshold), desk job complete, earnings within 24h if calendar known.
- Real copilot on backend (tool-calling LLM). On-device Gemini Nano optional for offline “what is my P/L” using cached book only.
- Thesis + invalidation fields.
- CSV export of lots.
- Quote cache on backend (Redis, 15s for last, 15m for history).
- Authenticated backend: device-pairing token (see §10.3). Open LAN mode flag `ALLOW_INSECURE_NOAUTH=1` for home lab only.
- NAV snapshot stored once per day (and on each quote refresh while open, throttled 15m) for drawdown.
- Earnings date from Yahoo calendar when available.
- Suitability flags for crypto and 3x ETFs (heuristic on ticker/`quoteType`).

### P2 — Could (advisor + PM depth)

- Risk questionnaire → suggested target allocation (60/40, 80/20, all-equity, custom) as **education**.
- Goals with target date and amount; % funded using current NAV (no stochastic engine required).
- FIFO sells + realized P/L + dividend transactions.
- Split adjustment tool (manual factor if Yahoo already adjusted, show “chart is split-adjusted”).
- Historical 95% 1-day book loss from stored NAV.
- Correlation matrix 90d.
- Scenario pack (§3.3).
- Weekly review generator (LLM, cached).
- Decision journal + 5/21/63d outcome vs regional benchmark (Tauric memory compatible).
- Peers + fundamentals snapshot panel.
- Tax holding-period hint (365d default).
- Backup to optional cloud account.
- Paper “if I add $X to TICKER” simulator (weights + concentration after).
- Position-size calculator: “1% of NAV risk with ATR stop” — labelled **calculator, not a recommendation**.
- Benchmark comparison chart.
- HTML/PDF one-pager export.

### P3 — Later

- Household / multiple books.
- Full Tauric `run_backtest` UI.
- iOS.
- Optional weekly email (user-composed, never silent).
- Advisor share-link (read-only, expiring).

---

## 9. Domain model

Use these names in API and Dart/SQL.

```
Device
  id, created_at, public_key_or_token_hash, label

UserAccount (optional)
  id, email, created_at

Book
  id, device_or_user_id, name, base_currency, benchmark_ticker,
  concentration_cap_pct, created_at

CashLedger
  id, book_id, ts, amount_base, note   # signed

Instrument
  ticker, name, exchange, quote_type, currency, sector, country, gics, as_of

Lot
  id, book_id, ticker, side (buy), qty, cost_per_share, cost_ccy,
  trade_date, inferred (bool), inference_note, created_at

Transaction
  id, book_id, ticker nullable, type (buy|sell|dividend|split|cash_in|cash_out|fee),
  qty, price, amount, ccy, ts, lot_id nullable, note

WatchItem
  id, book_id, ticker, thesis, created_at

Thesis
  ticker, book_id, thesis_text, invalidation_text, updated_at

Goal
  id, book_id, name, target_amount_base, target_date, priority

RiskProfile
  book_id, horizon_years, risk_score 1-5, answers_json

QuoteSnapshot
  ticker, last, prev_close, change_pct, currency, volume, high_52w, low_52w,
  sparkline[], as_of, session (pre|regular|post|closed)

NavSnapshot
  book_id, ts, nav_base, cost_base, u_pnl_base, realized_mtd_base

DeskJob
  id, book_id, ticker or "*", status (queued|running|succeeded|failed|cancelled),
  progress_step, created_at, finished_at, error

DeskReport
  job_id, ticker, source (tauric|local), rating, score,
  technicals, fundamentals, sentiment, news,
  bull, bear, research_manager, trader, risk, pm,
  final_trade_decision, trade_date, portfolio_context_hash, raw_json

Alert
  id, book_id, kind, title, body, tone, ts, read

ChatThread / ChatMessage
  role, text, citations[], created_at

DecisionJournal
  report_id, ticker, rating, nav_weight, mark,
  ret_5d, ret_21d, ret_63d, alpha_vs_benchmark  # filled later
```

**P/L rules**

- Unrealized lot P/L = `(mark_in_lot_ccy − cost_per_share) * qty`, then FX to base at latest FX rate (stamp the rate).
- Book NAV = sum of mark-to-market positions in base + cash.
- Realized P/L only from `sell` (and cash dividends as income, separate line).
- Default cost method: **average cost** on the holding card; FIFO available on lot detail in P2.
- Never convert a missing FX rate to `1`. If FX is missing, show native ccy and `FX n/a`.

**Inference rules (must match v0)**

See current `lib/data/position.dart`:

- Reference price = historical close on buy date if present else last.
- If qty and cost given and `cost > ref * qty * 2` → cost is **total dollars**, avg = cost/qty.
- Else if qty and cost → cost is **per share**.
- If only cost and `cost > ref * 5` → cost is **position value**, qty = cost/ref, avg = ref.
- Else if only cost → per share, qty default 1.
- If only date → avg = hist close, qty default 1.
- If neither → avg = last, qty default 1.
- Always store `inference_note` and show it on the lot.

---

## 10. Backend architecture

TradingAgents **cannot** run in the APK. v1 backend is a real service, not a 90-line script.

```
Android
  ├─ Yahoo (optional direct, for local-first quotes)
  └─ HTTPS API  (device token)
        │
        ▼
   API (FastAPI)
        │
        ├─ Postgres (books, lots, jobs, reports, nav)
        ├─ Redis (quote cache, job broker, rate limits)
        └─ Worker
              ├─ Market data (Yahoo, optional AV / FRED / EDGAR)
              ├─ Analytics (weights, risk, scenarios)
              ├─ Copilot LLM (tool loop)
              └─ TradingAgentsGraph.propagate(ticker, date, portfolio=...)
```

### 10.1 Stack (recommended default)

| Piece | Choice |
| --- | --- |
| API | Python 3.12, FastAPI, Pydantic v2, uvicorn |
| Worker | ARQ or Celery + Redis (ARQ is enough) |
| DB | PostgreSQL 16 |
| Cache / queue | Redis 7 |
| ORM | SQLAlchemy 2 + Alembic |
| Auth | Device token (P0), optional email magic-link (P1) |
| LLM desk | `tradingagents` package, pinned in `requirements.txt` |
| LLM copilot | Same provider keys, **separate** smaller/faster model |
| Observability | structured JSON logs, `/health`, `/ready` (db+redis) |
| Package | `docker compose` with `api`, `worker`, `postgres`, `redis` |

### 10.2 Tauric integration

Install from source: https://github.com/TauricResearch/TradingAgents (Apache-2.0).

```python
from tradingagents.graph.trading_graph import TradingAgentsGraph
from tradingagents.default_config import DEFAULT_CONFIG
from tradingagents.portfolio import PortfolioContext

config = DEFAULT_CONFIG.copy()
# env-driven: TRADINGAGENTS_LLM_PROVIDER, DEEP_THINK_LLM, QUICK_THINK_LLM, ...
graph = TradingAgentsGraph(debug=False, config=config)

portfolio = PortfolioContext.model_validate({
    "cash": 25000.0,
    "currency": "USD",
    "positions": [
        {"ticker": "NVDA", "quantity": 120, "average_price": 150.0},
    ],
})
state, decision = graph.propagate("NVDA", "2026-09-18", portfolio=portfolio)
```

Worker rules:

- Never run Tauric inside the FastAPI request thread.
- Serialize Tauric per process (graph may not be thread-safe); scale with worker replicas and a **per-ticker lock**.
- Persist full `state` JSON (seat reports) + `decision`.
- Map five-tier ratings: Buy / Overweight / Hold / Underweight / Sell (and Strong Buy / Strong Sell if the model emits them) onto the app’s `Rating` enum. Unparseable → `REVIEW` / Hold with `unparsed=true`.
- Inject decision-log path `TRADINGAGENTS_MEMORY_LOG_PATH` onto a volume.
- Checkpoints opt-in via env `TAURIC_CHECKPOINT=1`.
- If `tradingagents` is not installed, API still runs; jobs fail with `503 desk_unavailable` and the app uses local desk.

**Local desk (in the worker *and* on device)** must implement the same seat list so the UI does not change when the backend is down. Local desk is rules + Yahoo indicators (RSI, SMA20, window return, range, headlines) — acceptable as fallback, labelled `LOCAL TAPE`, never labelled `Tauric`.

### 10.3 Auth model

**P0 device pairing (default):**

1. App generates a random `device_id` + `device_secret` (256-bit), stored in secure storage.
2. First `POST /v1/devices/register` with optional `pairing_code` from the server’s `.env` (`BOOTSTRAP_PAIRING_CODE`) so a public VPS is not an open LLM wallet.
3. Server returns `access_token` (JWT, 30d) or opaque token.
4. All other routes: `Authorization: Bearer …`.

**LAN demo:** `ALLOW_INSECURE_NOAUTH=1` skips auth (prints a loud log). Forbidden in production compose overlay.

**P1 optional account:** magic link binds devices to a user for cloud backup of the book.

LLM provider keys: server env only (`OPENAI_API_KEY`, `GOOGLE_API_KEY`, …). Never echo back.

### 10.4 Rate limits and cost control

- Quote endpoints: 60/min/device.
- Copilot: 20/min/device, max 8 tool iterations, max 2k tokens out.
- Desk jobs: **1 running + 2 queued** per device. Duplicate ticker coalesces.
- Daily Tauric cap env `TAURIC_MAX_JOBS_PER_DAY` (default 20).

### 10.5 Market data

| Data | Primary | Fallback |
| --- | --- | --- |
| Search / last / history / FX | Yahoo `query1` then `query2` | Cached last snapshot |
| News | Yahoo search `newsCount` | Empty list |
| Fundamentals | Tauric vendors (yfinance, EDGAR) during desk | Yahoo summaryDetail if present |
| Macro | FRED if `FRED_API_KEY` | Omit |
| Sentiment | Tauric social vendor during desk | Session % / range percentile locally |

Yahoo is unofficial. Handle 429, missing `chart.result`, crypto, and Indian tickers. User-Agent required (see v0 client). Cache aggressively. Do not scrape Yahoo HTML.

---

## 11. HTTP API (v1)

Base: `/v1`. JSON. UTC ISO-8601. Money as strings **or** decimal numbers with 4–8 dp; do not use IEEE junk for cash (Python `Decimal` in, JSON float ok if rounded).

### 11.1 System

`GET /health` → `{ "ok": true, "version": "1.0.0" }`
`GET /ready` → `{ "ok": true, "postgres": true, "redis": true, "tauric": true|false }`

### 11.2 Devices

`POST /v1/devices/register` `{ "device_id", "pairing_code"? }` → `{ "access_token", "expires_at" }`

### 11.3 Book

`GET /v1/book` → book + lots + cash + watchlist + last marks
`PUT /v1/book/settings` `{ base_currency, benchmark_ticker, concentration_cap_pct }`
`POST /v1/book/cash` `{ "amount": 1000, "note": "salary" }`

`POST /v1/lots`
```json
{
  "query": "reliance",
  "ticker": "RELIANCE.NS",
  "qty": null,
  "cost": 185000,
  "buy_date": "2024-03-12",
  "note": "core holding"
}
```
Server may resolve Yahoo if `ticker` omitted. Returns lot + quote + `inference_note` + `concentration_warning`.

`PATCH /v1/lots/{id}` `{ qty?, cost_per_share?, note?, thesis? }`
`DELETE /v1/lots/{id}` — does not delete history if transactions exist; marks lot closed.

`POST /v1/watchlist` `{ "query" | "ticker" }`
`DELETE /v1/watchlist/{id}`

### 11.4 Market

`GET /v1/market/search?q=`
`GET /v1/market/quote?ticker=NVDA`
`GET /v1/market/history?ticker=NVDA&range=6mo`
`GET /v1/market/close?ticker=NVDA&date=2024-03-12`
`GET /v1/market/news?q=NVDA`

App **may** call Yahoo directly in local-first mode; when signed into backend, prefer `/v1/market/*` so cache and UA policy live in one place.

### 11.5 Analytics

`GET /v1/analytics/snapshot` → NAV, weights, sector, region, HHI, top names, beta (if possible), vol, max DD, flags
`GET /v1/analytics/scenarios` → packed scenarios
`POST /v1/analytics/what-if` `{ "ticker", "additional_cash_base" }` → new weights

### 11.6 Desk jobs

`POST /v1/jobs/desk`
```json
{ "ticker": "NVDA", "trade_date": null, "mode": "ticker" | "book" }
```
→ `{ "job_id", "status": "queued" }`

`GET /v1/jobs/{job_id}` → status, progress_step, report?
`GET /v1/desk/latest?ticker=NVDA`
`GET /v1/desk/history?ticker=NVDA`

When `mode=book`, worker runs PM-style review: analytics snapshot + Tauric on **top N names by weight** (N default 3, env `BOOK_REVIEW_TOP_N`) with shared `PortfolioContext`. Never silently run Tauric on 40 names.

### 11.7 Copilot

`POST /v1/copilot/turn`
```json
{ "thread_id": "...", "message": "Am I too concentrated?", "locale": "en" }
```
→ `{ "reply", "citations": [ { "kind": "weight", "ticker": "NVDA", "value": 0.28, "as_of": "..." } ], "tools_used": ["book_snapshot"] }`

### 11.8 Existing v0 compatibility

Keep `POST /v1/desk/analyze` as a **thin alias** that enqueues a job and **waits up to 180s** for old clients, but the Android v1 app must use the jobs API.

---

## 12. Android architecture

- Flutter 3.35+ / Dart 3.9+, Android 8+ (API 26), `applicationId` `com.mate4tech.sentientalpha` (do not collide with Gmail Agent `com.personal.gmail_agent`).
- State: `Riverpod` or `ChangeNotifier` — pick **Riverpod** for v1 (testability).
- Local DB: `drift` (SQLite). Secrets: `flutter_secure_storage`.
- HTTP: `dio` with timeouts (quotes 12s, jobs poll 10s, copilot 60s).
- Background: `workmanager` periodic 15m quote refresh when user enabled notifications.
- FCM for push (P1); in-app alerts work without it.
- Cleartext HTTP allowed **only** for private IPs in debug (`192.168/10/172.16`) so LAN backend still works.
- Theme: port `lib/theme.dart` tokens; do not switch to light theme in v1.
- Offline: last quotes + lots + last desk reports render with `STALE` / `OFFLINE` pills.
- On-device Gemini Nano: optional via ML Kit GenAI if the device has AICore; copilot setting Auto → Nano for questions that tools can answer from **local DB only**; otherwise backend.

**Never** embed provider API keys via `--dart-define` for OpenAI/Anthropic.

### 12.1 Local-first sync

- Lots always write locally first, then enqueue sync if a backend token exists.
- Conflict: last-write-wins per lot id, plus an `updated_at` clock. Show a banner if server rejected.
- Backend URL empty → never block Track.

---

## 13. AI systems

### 13.1 Desk (Tauric)

Seats to render, in order:

1. Technical / market
2. Fundamentals
3. Sentiment
4. News
5. Bull researcher
6. Bear researcher
7. Research manager (if present)
8. Trader plan
9. Risk (aggressive / conservative / neutral + judge)
10. Portfolio manager / final decision

UI copy: five-tier rating + 0–100 score if provided; if Tauric omits score, derive a display score only as a **label mapping** (Buy=75, Overweight=65, Hold=50, Underweight=35, Sell=25) and tag `score_derived=true`.

Portfolio-aware prompt context the adapter must pass:

- cash, base ccy
- each position: ticker, qty, avg, weight %, uPnL %
- concentration cap
- stated goal (if any)

### 13.2 Copilot tools (strict)

The model gets **no raw web**. Tools:

| Tool | Returns |
| --- | --- |
| `search_instruments(q)` | Yahoo hits |
| `get_quote(ticker)` | last, %, as-of |
| `get_book()` | lots, cash, weights, uPnL |
| `get_desk(ticker)` | last report summary |
| `get_analytics()` | HHI, top names, scenarios |
| `get_calendar(ticker)` | earnings/ex-div if known |
| `what_if(ticker, cash)` | new weights |

System prompt must include: disclaimer, “if tools don’t have it, say you don’t know”, “never instruct a market order”, “crypto is high risk”, “you are not an adviser”.

On-device Nano: only `get_book` / last quotes from SQLite. If the user asks for a new ticker desk, say they need the cloud desk.

### 13.3 Weekly review (P2)

One LLM call with `get_book` + `get_analytics` + last desk ratings + calendar. Output markdown sections: Moved, Crowded, Coming up, Drift vs target, Questions to sit with. Cache 12 hours. Not a trade blotter.

---

## 14. Analytics definitions (implement exactly)

Let \(w_i\) be market-value weight of position \(i\) in **NAV including cash**.

- **HHI** = \(\sum w_i^2\) (including cash). Report `1/HHI` as effective-N.
- **Top name** = max equity weight excluding cash.
- **Concentration flag** if top name ≥ cap (default 0.25) or any sector ≥ 0.40 (when sector known).
- **Beta**: 90d daily covariance(book excess, benchmark excess) / var(benchmark), if ≥ 40 overlapping return days; else omit.
- **Vol**: stdev of book daily returns * sqrt(252), 90d window, if ≥ 20 days.
- **Max drawdown**: peak-to-trough of stored NAV series; if < 10 NAV points, omit.
- **Scenario −10% names:** \(\sum w_i \times (-0.10) \times NAV\) for equities/crypto; cash 0.
- **Scenario largest −30%:** that name’s MV * −0.30.
- **Correlation:** Pearson on 90d daily returns; need ≥ 40 days both names.

Do not display Sharpe until a risk-free series exists.

Sector map: use vendor GICS/Yahoo sector; unknown is `Unclassified`, never guessed from the ticker string except `BTC-USD`/`ETH-USD` → asset class `Crypto`.

Asset class rules:

- `EQUITY` / `ETF` → Equity (ETF further `ETF` subclass if quoteType says ETF)
- `CRYPTOCURRENCY` or ticker matching `*-USD` crypto → Crypto
- `MUTUALFUND` → Fund
- cash ledger → Cash
- otherwise `Other`

---

## 15. Notifications and monitor

**While app is in foreground:** 45s (user-configurable) Yahoo/backend re-quote. Same alerts as v0 plus:

- Desk job completed / failed
- Concentration cap breached after a mark-to-market (price run-up)

**Background (P1):** 15m WorkManager; FCM from backend if marks cross thresholds server-side (requires sync).

Quiet hours default 22:00–07:00 local, user-editable. Cost-cross still allowed if user opts in `always_cost_cross`.

Do not run Tauric in the background.

---

## 16. Security, privacy, compliance

- Lots are personal financial data. Encrypt local DB at rest if the plugin allows (SQLCipher or OS file encryption + `encryptedSharedPreferences`).
- TLS for non-LAN. Certificate pinning optional P2.
- Pairing code on any hosted backend.
- CORS: do not use `allow_origins=["*"]` in production compose.
- Redact tokens, keys, emails in logs.
- Yahoo ToS: personal use, cache, no resale of a quote API.
- TradingAgents attribution in About.
- GDPR-ish: export JSON (already), delete book (settings).
- No analytics SDK required; if added, it must be opt-in and must not send lot-level data.

---

## 17. Visual / UX spec (must not regress)

Port from v0:

- `SA` color tokens in `lib/theme.dart`
- Terminal header with live pill and `LOCAL DESK` / `TAURIC LINKED`
- JetBrains Mono for tickers, times, P/L
- Cards with 12–16 radius, hairline `#14FFFFFF`
- Primary CTA mint; destructive coral
- Rating colors: buy mint, hold cyan, sell coral

Copy tone: concise, professional, no meme stock slang, no “to the moon”. Prefer “mark”, “lot”, “book”, “desk”, “uPnL”.

Empty Track CTA subtitle: `Name or ticker · cost or buy date · we look up the rest`

---

## 18. Phased delivery plan (agent schedule)

Work in this order. Do not start P2 UI before P0 tests pass.

### Phase P0 — days 1–N until APK + compose run

1. Scaffold monorepo, docker-compose, empty FastAPI health.
2. Drift schema: book, lots, quotes, alerts.
3. Port Yahoo client + `inferPosition` with unit tests (Dart **and** Python — same cases).
4. Track screen + lot list + 45s refresh + cost-cross / 3% alerts.
5. Local desk port + Desk screen.
6. Worker + `TradingAgents` optional import + jobs API + PortfolioContext.
7. Settings backend URL + pairing.
8. Disclaimer onboarding.
9. `flutter test`, `pytest`, `flutter build apk --release`.
10. GitHub Actions release workflow.

**P0 exit:** A reviewer can sideload the APK, add `AAPL` with a date, see a mark and a local desk without any server; then `docker compose up`, paste URL, run desk, see `source=tauric` or a clean fallback message.

### Phase P1

Book tab weights, FX, watchlist, copilot tools, FCM optional, quote cache, auth, NAV snapshots, earnings if present, CSV export, concentration dialog.

### Phase P2

Goals, questionnaire, FIFO/dividends, scenarios, weekly review, journal outcomes, peers/fundamentals panel, what-if, position-size calculator, PDF/HTML one-pager.

---

## 19. Test matrix (minimum)

### Dart

- `inferPosition` — all branches in §9 (table of 8 cases).
- Unrealized P/L and weights with two lots, two currencies (FX present and FX missing).
- Concentration warning fires at 25%+1 bp.
- Cost-cross alert when previous mark and new mark straddle avg cost.
- Local desk rating enum parse (strong buy … strong sell, overweight, underweight, reduce).
- Widget: Track add lot with FakeMarkets (pattern already in `test/widget_test.dart`).

### Python

- `POST /v1/lots` inference matches Dart cases (±0.01).
- Jobs: enqueue, fake graph returns seats, poll succeeded.
- Jobs: graph import missing → 503, app-contract error body.
- `PortfolioContext` built from lots+cash.
- Analytics HHI for equal 4 names = 0.25.
- Auth: no token 401 when `ALLOW_INSECURE_NOAUTH=0`.
- Copilot: tool loop cannot call network except tool implementations; prompt injection “ignore tools and buy” still only returns text + disclaimer.

### Manual

- `RELIANCE.NS`, `7203.T`, `0700.HK`, `BTC-USD`, `AAPL`.
- Backend down mid-job → UI fallback.
- Airplane mode: book still visible.

---

## 20. Greenfield repo layout

Implement **in the GitHub repo root** (this folder when publishing only Sentient Alpha):

```
/
  README.md
  docs/
    REQUIREMENTS.md          # this file
    ARCHITECTURE.md          # keep, update to v1 diagram
  mobile/                    # Flutter app
    lib/
    test/
    android/
    pubspec.yaml
  backend/
    app/
      api/                   # FastAPI routers
      workers/               # ARQ tasks
      analytics/
      market/                # Yahoo
      desk/                  # local + tauric adapter
      copilot/
      models/
    alembic/
    tests/
    requirements.txt
    Dockerfile
  docker-compose.yml
  docker-compose.prod.yml    # no INSECURE, TLS reverse proxy notes
  .github/workflows/release.yml
  .env.example
```

Do not check in `.env`, APK binaries, or `~/.tradingagents` memory.

`.env.example` keys:

```
BOOTSTRAP_PAIRING_CODE=
ALLOW_INSECURE_NOAUTH=0
DATABASE_URL=postgresql://...
REDIS_URL=redis://redis:6379/0
TAURIC_MAX_JOBS_PER_DAY=20
BOOK_REVIEW_TOP_N=3
TRADINGAGENTS_LLM_PROVIDER=openai
OPENAI_API_KEY=
GOOGLE_API_KEY=
ANTHROPIC_API_KEY=
FRED_API_KEY=
ALPHA_VANTAGE_API_KEY=
SEC_EDGAR_USER_AGENT=SentientAlpha your@email.com
TRADINGAGENTS_MEMORY_LOG_PATH=/data/trading_memory.md
```

---

## 21. Implementation playbook (commands the agent should make work)

```bash
# backend
docker compose up --build
curl -s localhost:8000/health

# mobile
cd mobile && flutter pub get && flutter test && flutter run
flutter build apk --release
```

README must document:

1. Sideload APK (unknown sources).
2. Use without backend.
3. Run compose, pair device, paste URL.
4. Optional: clone TradingAgents, `pip install .` into the worker image, set LLM keys.
5. Disclaimer.

Release: tag `v*` → Actions builds `sentient-alpha.apk` onto GitHub Releases.

---

## 22. Recommended defaults (do not block on the user)

| Question | Default |
| --- | --- |
| Auth | Device pairing + optional `ALLOW_INSECURE_NOAUTH` |
| State management | Riverpod |
| Local DB | Drift |
| Job queue | ARQ + Redis |
| Copilot model | Same provider as Tauric `quick_think_llm` |
| Refresh | 45s |
| Concentration cap | 25% |
| Base currency | USD until user sets it (offer INR/EUR/JPY/HKD/GBP on onboarding) |
| Benchmark | `SPY` if base USD; `^NSEI` if INR; `^N225` if JPY; `^HSI` if HKD; else `SPY` |
| Cost method | Average on cards, FIFO in P2 detail |
| Tax hint jurisdiction | US 365-day, labelled as hint |
| Pairing | Required when not insecure |
| Analytics when data missing | Omit the metric, never fabricate |
| Language | English UI; Tauric `output_language` env if set |
| Application id | `com.mate4tech.sentientalpha` |
| First Tauric run | On explicit `Run desk`, **not** automatically on every new lot (auto-run **local** desk only, to save tokens). User can toggle `auto_tauric_on_add` default off. |

---

## 23. Acceptance criteria (v1 “done”)

A product owner with a phone and a laptop can:

1. Install the APK, accept the disclaimer, skip account, add `AAPL` with buy date only → qty 1, cost = that day’s close, live mark, local desk seats fill.
2. Add `RELIANCE.NS` with a rupee total much larger than price → inferred shares, note visible.
3. See two names on Track with uPnL and weights after opening Book.
4. Turn on docker-compose with pairing code, paste URL, Run desk on NVDA → job progress → Tauric seats **or** a clear fallback. Keys never appear in the app.
5. Ask Copilot “am I too concentrated?” and get an answer that cites actual weights, not a generic essay.
6. Receive an in-app alert when a name crosses cost or moves 3% while the app is open.
7. Export CSV of lots.
8. Airplane mode: lots and last marks remain.
9. README + Releases APK path work.
10. `flutter test` and `pytest` green in CI.

P1/P2 features in §8 are **not** required to call P0 done, but the architecture in P0 must not block them (tables and routes reserved).

---

## 24. Copy blocks (use as-is)

**Track CTA:** `Track with AI desk`

**Local pill:** `LOCAL DESK`

**Cloud pill:** `TAURIC LINKED`

**Job pill:** `DESK RUNNING`

**Inference qty default:** `Quantity defaulted to 1 — edit the lot if you hold more.`

**Backend down:** `Tauric backend unreachable — fell back to the local desk.`

**Not advice (short):** `Informational only — not a trade instruction.`

**Crypto flag:** `Crypto is high volatility and can go to zero. This is a suitability flag, not a ban.`

**Concentration:** `This lot would make {ticker} {pct}% of the book (cap {cap}%). Save anyway?`

---

## 25. Reference map (v0 code to steal, not to worship)

| v0 file | Reuse |
| --- | --- |
| `lib/theme.dart` | Color/type tokens |
| `lib/data/position.dart` | Inference — port 1:1 + tests |
| `lib/data/yahoo.dart` | URL fallbacks, UA, chart parse |
| `lib/data/desk.dart` | Local seat text + score heuristic as fallback |
| `lib/data/models.dart` | Rating/Rec enums |
| `tauric_backend/app.py` | Field names of Tauric state |
| `ARCHITECTURE.md` | Why keys cannot live in the APK |
| `test/widget_test.dart` | FakeMarkets pattern |

Replace: canned `copilot.dart`, single-lot replace-on-add, sync 180s `analyze`, open CORS, `shared_preferences` as the only store.

---

## 26. Success metrics (product, not vanity)

The app is succeeding if a real person:

- Can reconstruct a 5–15 name international book in under 10 minutes.
- Can answer “what am I actually exposed to?” without a spreadsheet.
- Can see the Tauric debate **and** the book context together.
- Is never surprised by a silent trade, a vanished lot, or a number without a currency and a time.

If those are true, extra animations do not matter.

---

*End of requirements. Implement P0 first. Do not ask the product owner to restate U1–U15.*
