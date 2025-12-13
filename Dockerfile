# Stage 1: Build dependencies
FROM python:3.12-slim AS builder

# Install build dependencies only
RUN apt-get update && apt-get install -y --no-install-recommends \
  git \
  build-essential \
  libxslt1-dev \
  libxml2-dev \
  libffi-dev \
  libssl-dev \
  && rm -rf /var/lib/apt/lists/*

# Create virtual environment and install Python packages
RUN python3 -m venv /opt/searx-pyenv && \
  /opt/searx-pyenv/bin/pip install --no-cache-dir --upgrade pip setuptools wheel pyyaml

# Clone SearXNG and install dependencies
RUN git clone --depth 1 "https://github.com/searxng/searxng" /opt/searxng-src && \
  /opt/searx-pyenv/bin/pip install --no-cache-dir -r /opt/searxng-src/requirements.txt && \
  /opt/searx-pyenv/bin/pip install --no-cache-dir --no-build-isolation /opt/searxng-src && \
  /opt/searx-pyenv/bin/pip install --no-cache-dir uwsgi

# Stage 2: Runtime
FROM python:3.12-slim

# Install runtime dependencies only (removed uwsgi and uwsgi-plugin-python3)
RUN apt-get update && apt-get install -y --no-install-recommends \
  libxslt1.1 \
  libxml2 \
  bash \
  gettext \
  supervisor \
  redis-server \
  git \
  && rm -rf /var/lib/apt/lists/*

# Create users and directories in one layer (redis user already exists from redis-server package)
RUN groupadd -r searxng && useradd -r -g searxng -d /usr/local/searxng -s /bin/bash searxng && \
  mkdir -p /usr/local/searxng /etc/searxng /var/cache/searxng /var/lib/redis /var/log/redis /var/log/supervisor && \
  chown -R searxng:searxng /usr/local/searxng /var/cache/searxng && \
  chown -R redis:redis /var/lib/redis /var/log/redis

# Copy built application from builder
COPY --from=builder --chown=searxng:searxng /opt/searx-pyenv /usr/local/searxng/searx-pyenv
COPY --from=builder --chown=searxng:searxng /opt/searxng-src /usr/local/searxng/searxng-src

# Copy configuration files
COPY settings/settings.yml /etc/searxng/settings.yml.template
COPY settings/limiter.toml /etc/searxng/limiter.toml
COPY settings/uwsgi.ini /etc/searxng/uwsgi.ini
RUN chown -R searxng:searxng /etc/searxng

# Create supervisor configuration template
RUN echo '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/var/log/supervisor/supervisord.log\n\
pidfile=/var/run/supervisord.pid\n\
\n\
[program:redis]\n\
command=/usr/bin/redis-server --bind 127.0.0.1 --port 6379 --dir /var/lib/redis\n\
user=redis\n\
autostart=REDIS_AUTOSTART\n\
autorestart=true\n\
stdout_logfile=/var/log/redis/redis.log\n\
stderr_logfile=/var/log/redis/redis.log\n\
priority=1\n\
\n\
[program:searxng]\n\
command=/usr/local/searxng/searx-pyenv/bin/uwsgi --ini /etc/searxng/uwsgi.ini --http-socket :8080\n\
user=searxng\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
priority=2\n\
directory=/usr/local/searxng/searxng-src' > /etc/supervisor/conf.d/searxng.conf.template

# Create entrypoint script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Set default values\n\
export SEARXNG_PORT=${SEARXNG_PORT:-8080}\n\
\n\
# Check if REDIS_URL is provided by user\n\
if [ -z "$REDIS_URL" ]; then\n\
  # No REDIS_URL provided - use internal Redis\n\
  echo "Using internal Redis"\n\
  export REDIS_URL=redis://127.0.0.1:6379/0\n\
  REDIS_AUTOSTART=true\n\
else\n\
  # REDIS_URL provided - check if external\n\
  if [[ "$REDIS_URL" == *"127.0.0.1"* ]] || [[ "$REDIS_URL" == *"localhost"* ]]; then\n\
    echo "Using internal Redis (localhost)"\n\
    REDIS_AUTOSTART=true\n\
  else\n\
    echo "Using external Redis: $REDIS_URL"\n\
    REDIS_AUTOSTART=false\n\
  fi\n\
fi\n\
\n\
# Substitute environment variables in settings.yml\n\
envsubst < /etc/searxng/settings.yml.template > /etc/searxng/settings.yml\n\
chown searxng:searxng /etc/searxng/settings.yml\n\
\n\
# Create supervisor config from template\n\
sed "s/REDIS_AUTOSTART/$REDIS_AUTOSTART/g; s/:8080/:${SEARXNG_PORT}/g" /etc/supervisor/conf.d/searxng.conf.template > /etc/supervisor/conf.d/searxng.conf\n\
\n\
# Start supervisord\n\
exec /usr/bin/supervisord -c /etc/supervisor/supervisord.conf' > /entrypoint.sh && \
chmod +x /entrypoint.sh

EXPOSE 8080

ENV SEARXNG_SETTINGS_PATH=/etc/searxng/settings.yml
ENV UWSGI_WORKERS=4
ENV UWSGI_THREADS=4
ENV SEARXNG_PORT=8080

WORKDIR /usr/local/searxng/searxng-src

ENTRYPOINT ["/entrypoint.sh"]
