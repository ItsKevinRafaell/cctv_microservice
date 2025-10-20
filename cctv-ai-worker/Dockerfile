FROM python:3.10-slim
ENV TF_CPP_MIN_LOG_LEVEL=2
WORKDIR /app
COPY requirements.txt .
RUN apt-get update && apt-get install -y libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*
RUN python -m pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "worker.py"]
