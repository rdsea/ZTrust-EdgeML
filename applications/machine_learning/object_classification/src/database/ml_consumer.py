import asyncio
import json
import logging
import sys
import time
from multiprocessing import Process, current_process

import aio_pika
import yaml
from motor.motor_asyncio import AsyncIOMotorClient

MAX_RETRIES = 10
INITIAL_DELAY = 2
MAX_DELAY = 60
NUM_PROCESSES = 4  # Number of parallel worker processes

# Load config once at the top-level to avoid re-reading in each process
with open("config.yaml") as f:
    ml_consumer_config = yaml.safe_load(f)


def get_rabbitmq_connection_url(config):
    return f"amqp://{config['rabbitmq']['username']}:{config['rabbitmq']['password']}@{config['rabbitmq']['url']}"


def get_mongodb_connection_url(config):
    return f"mongodb://{config['mongodb']['username']}:{config['mongodb']['password']}@{config['mongodb']['url']}"


RABBITMQ_URL = get_rabbitmq_connection_url(ml_consumer_config)
QUEUE_NAME = ml_consumer_config["rabbitmq"]["queue_name"]
MONGODB_URI = get_mongodb_connection_url(ml_consumer_config)
DB_NAME = "object-detection"
COLLECTION_NAME = "results"

logging.basicConfig(level=logging.INFO)


async def process_message(message: aio_pika.IncomingMessage, collection):
    async with message.process():
        try:
            body = message.body.decode()
            data = json.loads(body)
            data["Endtime"] = time.time()
            logging.info(f"{current_process().name} received: {data}")
            result = await collection.insert_one(data)
            logging.info(f"{current_process().name} inserted ID: {result.inserted_id}")
        except Exception as e:
            logging.error(f"Error: {e}")


async def consume():
    mongo_client = AsyncIOMotorClient(MONGODB_URI)
    collection = mongo_client[DB_NAME][COLLECTION_NAME]

    retries = 0
    delay = INITIAL_DELAY

    while retries < MAX_RETRIES:
        try:
            connection = await aio_pika.connect_robust(RABBITMQ_URL)
            break
        except Exception as e:
            logging.warning(f"Connection failed: {e}. Retrying in {delay}s...")
            await asyncio.sleep(delay)
            retries += 1
            delay = min(delay * 2, MAX_DELAY)
    else:
        logging.error("Exceeded max retries to connect to RabbitMQ.")
        sys.exit(1)

    async with connection:
        channel = await connection.channel()
        queue = await channel.declare_queue(QUEUE_NAME, durable=True)
        logging.info(f"{current_process().name} consuming from queue: {QUEUE_NAME}")
        await queue.consume(lambda msg: process_message(msg, collection))
        await asyncio.Future()  # Keep running


def start_worker():
    asyncio.run(consume())


if __name__ == "__main__":
    processes = [
        Process(target=start_worker, name=f"Worker-{i}") for i in range(NUM_PROCESSES)
    ]

    for p in processes:
        p.start()

    for p in processes:
        p.join()
