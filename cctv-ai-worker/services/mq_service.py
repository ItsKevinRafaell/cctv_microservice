# cctv-ai-worker/services/mq_service.py
import pika
import time

class RabbitMQService:
    def __init__(self, host, queue_name):
        self.host = host
        self.queue_name = queue_name
        self.connection = None
        
        # Coba hubungkan beberapa kali sebelum menyerah
        max_retries = 10
        retry_delay = 5  # detik
        for i in range(max_retries):
            try:
                print(f"SERVICE Mencoba terhubung ke RabbitMQ (percobaan {i+1}/{max_retries})...")
                self.connection = pika.BlockingConnection(pika.ConnectionParameters(host=self.host))
                print("✅ Berhasil terhubung ke RabbitMQ!")
                break # Keluar dari loop jika berhasil
            except pika.exceptions.AMQPConnectionError as e:
                print(f" SERVICE koneksi gagal: {e}. Mencoba lagi dalam {retry_delay} detik...")
                time.sleep(retry_delay)
        
        if not self.connection:
            raise Exception("SERVICE Gagal terhubung ke RabbitMQ setelah beberapa kali percobaan.")

        self.channel = self.connection.channel()
        self.channel.queue_declare(queue=self.queue_name, durable=True)

        self.channel.basic_qos(prefetch_count=1)


    def consume_tasks(self, callback_function):
        print(f"[*] Menunggu pesan di antrian '{self.queue_name}'. Untuk keluar, tekan CTRL+C")
        self.channel.basic_consume(queue=self.queue_name, on_message_callback=callback_function)
        self.channel.start_consuming()

    def close(self):
        if self.connection and self.connection.is_open:
            self.connection.close()