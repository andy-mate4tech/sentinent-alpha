# Tauric backend for the Sentient Alpha APK

Thin FastAPI adapter. The phone POSTs `/v1/desk/analyze`; this process calls `TradingAgentsGraph.propagate(ticker, date)`.

See `../ARCHITECTURE.md` for the full diagram.

```bash
git clone https://github.com/TauricResearch/TradingAgents.git
pip install ./TradingAgents
pip install -r requirements.txt
export OPENAI_API_KEY=...
uvicorn app:app --host 0.0.0.0 --port 8000
```

Then paste `http://<this-host>:8000` into the app About tab.
