# Sentient Alpha

Personal AI research terminal for stocks, ETFs, and crypto.  
**RESEARCH TERMINAL · NOT ADVICE**

Android (Flutter) + FastAPI/ARQ backend with optional [Tauric Research TradingAgents](https://github.com/TauricResearch/TradingAgents) (Apache-2.0).

## Quick start

### 1) Backend (Docker)

```bash
cd /opt/andy-apps/sentient-alpha
cp .env.example .env
# Lab mode already has ALLOW_INSECURE_NOAUTH=1
docker compose up --build -d
curl -s localhost:8010/health
```

API: `http://<host>:8010`

### 2) LLM bridge (kimi-cli / cursor-cli — until DeepSeek key)

`docker compose up` starts **`llm-bridge`** on `:8099` (OpenAI-compatible). It mounts this host’s `kimi-code` install and talks to the worker on the compose network.

```bash
# optional: change provider
# LLM_CLI_PROVIDER=cursor   # in .env
# LLM_MODE=cli
```

When you have DeepSeek:

```bash
# in .env
LLM_MODE=deepseek
DEEPSEEK_API_KEY=sk-...
docker compose up -d --force-recreate api worker llm-bridge
```

Host-only bridge (if you prefer not to use the compose service):

```bash
./scripts/run-llm-bridge.sh   # :8099
```

### 3) Mobile (Flutter)

```bash
export PATH="/opt/flutter/bin:$PATH"
cd mobile
flutter pub get
flutter test
flutter run          # device/emulator
flutter build apk --release
# APK: build/app/outputs/flutter-apk/app-release.apk
```

**Without backend:** install APK → accept disclaimer → Track `AAPL` with a buy date → local desk fills.

**With backend:** More → paste `http://<lan-ip>:8010` → Save & test → Desk → Run desk.

### 4) Pairing (production)

Set `ALLOW_INSECURE_NOAUTH=0` and `BOOTSTRAP_PAIRING_CODE=...`. App sends the code on register.

## Layout

```
mobile/     Flutter Android app (com.mate4tech.sentientalpha)
backend/    FastAPI + ARQ worker
vendor/TradingAgents/   Apache-2.0 upstream (optional install)
docs/       REQUIREMENTS + ARCHITECTURE
```

## Desk sources

| Source | When |
| --- | --- |
| `local` | Always — Yahoo tape heuristics on device/backend |
| `cli` | kimi-cli / cursor-agent via LLM bridge |
| `tauric` | TradingAgentsGraph when package + LLM reachable |

Keys **never** ship in the APK.

## Tests

```bash
cd backend && pip install -r requirements.txt && pytest -q
cd mobile && flutter test
```

## Release

Tag `v*` → GitHub Actions publishes `sentient-alpha.apk`.

## Disclaimer

See in-app About / first launch. Informational only — not financial advice.
