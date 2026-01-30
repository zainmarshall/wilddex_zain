# syntax=docker/dockerfile:1
# Multi-stage build for smaller final image

FROM python:3.11-slim AS base
ENV PYTHONDONTWRITEBYTECODE=1 \
        PYTHONUNBUFFERED=1 \
        DEBIAN_FRONTEND=noninteractive \
        PIP_DEFAULT_TIMEOUT=180 \
        PIP_DISABLE_PIP_VERSION_CHECK=1 \
        PIP_RETRIES=10 \
        PIP_PROGRESS_BAR=off

# Install minimal system deps (OpenCV runtime libs) with retry logic for hash / network issues
RUN set -eux; \
        for i in 1 2 3; do \
                echo "APT install attempt $i"; \
                apt-get update && \
                apt-get install -y --no-install-recommends \
                        libgl1 \
                        libglib2.0-0 \
                && break || { echo "APT attempt $i failed; cleaning & retrying"; rm -rf /var/lib/apt/lists/*; sleep 2; }; \
                if [ "$i" = 3 ]; then exit 1; fi; \
        done; \
        rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install dependencies first (better layer caching) with retry loop for large wheels
COPY requirements.txt ./
RUN set -eux; \
        for i in 1 2 3; do \
                pip install --no-cache-dir -r requirements.txt && break || { echo "pip install attempt $i failed"; sleep 10; }; \
                if [ "$i" = 3 ]; then exit 1; fi; \
        done

# Copy application code
COPY . .

# Expose port (Cloud Run uses $PORT env)
ENV PORT=8080
EXPOSE 8080

# Use uvicorn to serve FastAPI
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT}"]
