import asyncio
import json
import logging

import aio_pika
import yaml


# Load configuration
def get_rabbitmq_connection_url(config: dict):
    rabbitmq_url = config["rabbitmq"]["url"]
    username = config["rabbitmq"]["username"]
    password = config["rabbitmq"]["password"]
    return f"amqp://{username}:{password}@{rabbitmq_url}"


ml_config = yaml.safe_load(open("config.yaml"))
RABBITMQ_URL = get_rabbitmq_connection_url(ml_config)
QUEUE_NAME = ml_config["rabbitmq"]["queue_name"]

# Set up logging
logging.basicConfig(level=logging.INFO)


async def publish_message(message: dict):
    connection = await aio_pika.connect_robust(RABBITMQ_URL)
    async with connection:
        channel = await connection.channel()
        await channel.default_exchange.publish(
            aio_pika.Message(body=json.dumps(message).encode()),
            routing_key=QUEUE_NAME,
        )
        logging.info(f"Published message: {message}")


if __name__ == "__main__":
    # Sample message (customize as needed)
    sample_data = {
        "image_id": "123456",
        "detections": [
            {"label": "person", "confidence": 0.98, "bbox": [10, 20, 50, 60]},
            {"label": "car", "confidence": 0.88, "bbox": [100, 120, 200, 260]},
        ],
    }

    asyncio.run(publish_message(sample_data))
