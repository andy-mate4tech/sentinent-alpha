FROM python:3.12-slim-bookworm

ARG INSTALL_TAURIC=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY vendor/TradingAgents /opt/TradingAgents
RUN if [ "$INSTALL_TAURIC" = "1" ]; then \
      pip install --no-cache-dir -e /opt/TradingAgents || echo "TradingAgents optional install failed"; \
    fi

COPY backend/ /app/

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONPATH=/app \
    TRADINGAGENTS_MEMORY_LOG_PATH=/data/trading_memory.md

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
