FROM python:3.12-slim

ARG BUILD_DATE
LABEL org.opencontainers.image.created="${BUILD_DATE}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    devpi-server \
    devpi-web \
    devpi-constrained \
    devpi-client

RUN mkdir -p /data/devpi /etc/devpi

COPY allowed.txt /etc/devpi/allowed.txt
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

VOLUME ["/data/devpi"]

EXPOSE 3141

ENV DEVPI_DATA_DIR=/data/devpi \
    DEVPI_PORT=3141 \
    DEVPI_HOST=0.0.0.0 \
    DEVPI_USER=pypi \
    DEVPI_INDEX=constrained \
    ALLOWED_FILE=/etc/devpi/allowed.txt

ENTRYPOINT ["/entrypoint.sh"]
