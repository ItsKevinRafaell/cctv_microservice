FROM python:3.10-slim
ENV TF_CPP_MIN_LOG_LEVEL=2
WORKDIR /app
COPY requirements.txt .
RUN python -m pip install --upgrade pip setuptools wheel \
 && pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "worker.py"]
