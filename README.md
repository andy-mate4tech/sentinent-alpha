# Sentient Alpha

No-login Android stock tracker. Type a name or ticker, add **cost** or a **buy date**. Yahoo Finance fills last price (and historical close if you gave a date). A local desk, modeled on [TauricResearch/TradingAgents](https://github.com/TauricResearch/TradingAgents), scores the tape and re-quotes about every 45 seconds.

**Build v1 from scratch:** Cursor (and any coding agent) must follow **[docs/REQUIREMENTS.md](docs/REQUIREMENTS.md)** — complete backend, AI Android app, analyst / advisor / portfolio-manager features, APIs, tests, and phase plan. This folder’s current app is **v0 reference only**.

Lots stay on the phone. No account. No app server.

**[Download APK (GitHub Releases)](https://github.com/andy-mate4tech/sentinent-alpha/releases/latest)**

Direct: [sentient-alpha.apk](https://github.com/andy-mate4tech/sentinent-alpha/releases/download/v3.0.0/sentient-alpha.apk)

On the phone: Settings → allow install from this source → open the APK. Ratings are **research / informational, not advice**.

## Use

1. **Track** — name or ticker, optional quantity, cost or buy date → **Track with AI desk**
2. **Desk** — pick a lot, run the Tauric seats (local or backend)
3. **Copilot** — ask about P/L or how Tauric is wired
4. **About** — optional backend URL (`http://192.168.x.x:8000`)

Tickers Yahoo covers work, including `AAPL`, `RELIANCE.NS`, `7203.T`, `0700.HK`, `BTC-USD`.

The real Tauric firm is Python + LLM keys and **cannot run inside the APK**. Optional: stand up `tauric_backend/` and paste the URL in **About**. Full wiring is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Run from source

```bash
flutter pub get
flutter test
flutter run
flutter build apk --release
```

## Real TradingAgents

```bash
git clone https://github.com/TauricResearch/TradingAgents.git
pip install ./TradingAgents
pip install -r tauric_backend/requirements.txt
export OPENAI_API_KEY=...
cd tauric_backend
uvicorn app:app --host 0.0.0.0 --port 8000
```

Then save that origin in the About tab.
