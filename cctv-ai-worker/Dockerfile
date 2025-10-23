FROM python:3.10-slim

ENV TF_CPP_MIN_LOG_LEVEL=2 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

ARG PYTORCH_INDEX_URL=https://download.pytorch.org/whl/cpu

WORKDIR /app
COPY requirements.txt .
RUN apt-get update \
    && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*
RUN python -m pip install --upgrade pip setuptools wheel \
    && pip install --extra-index-url ${PYTORCH_INDEX_URL} -r requirements.txt
COPY . .
CMD ["python", "worker.py"]
