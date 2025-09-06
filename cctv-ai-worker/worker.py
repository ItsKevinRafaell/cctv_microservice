import os
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
print("CUDA_VISIBLE_DEVICES =", os.environ.get("CUDA_VISIBLE_DEVICES"))

import json
import sys
from core.processor import VideoProcessor
from services.mq_service import RabbitMQService
from services.reporting_service import ReportingService

RABBITMQ_HOST = 'rabbitmq'
MAIN_BACKEND_HOST = 'api_main'
QUEUE_NAME = 'video_analysis_tasks'
MAIN_BACKEND_URL = f'http://{MAIN_BACKEND_HOST}:8080'
MODEL_PATH = "mod.h5"

def main():
    mq_service = RabbitMQService(host=RABBITMQ_HOST, queue_name=QUEUE_NAME)
    reporting_service = ReportingService(base_url=MAIN_BACKEND_URL)
    video_processor = VideoProcessor(reporting_service=reporting_service, model_path=MODEL_PATH)

    def on_task_received(ch, method, properties, body):
        print(f"\n [x] Menerima tugas baru: {body.decode(errors='ignore')}")
        try:
            task = json.loads(body)
            video_processor.analyze(task)
            ch.basic_ack(delivery_tag=method.delivery_tag)
        except Exception as e:
            print(f" [!] Task gagal: {e} -> NACK & requeue")
            ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

    try:
        mq_service.consume_tasks(on_task_received)
    except KeyboardInterrupt:
        print('Interrupted')
        mq_service.close()
        sys.exit(0)
    except Exception as e:
        print(f" [!] Terjadi kesalahan fatal: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
