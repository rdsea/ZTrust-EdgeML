import asyncio
import json
import logging
import os
import sys
import time
from multiprocessing import Process, current_process

import aio_pika
import yaml
from motor.motor_asyncio import AsyncIOMotorClient

MAX_RETRIES = 10
INITIAL_DELAY = 2
MAX_DELAY = 60
NUM_PROCESSES = 4

# Load config once
with open("config.yaml") as f:
    ml_consumer_config = yaml.safe_load(f)


def get_rabbitmq_connection_url(config):
    return f"amqp://{config['rabbitmq']['username']}:{config['rabbitmq']['password']}@{config['rabbitmq']['url']}"


def get_mongodb_connection_url(config):
    return f"mongodb://{config['mongodb']['username']}:{config['mongodb']['password']}@{config['mongodb']['url']}"


def get_rabbitmq_connection_url_openziti(config):
    return f"amqp://{config['rabbitmq']['username']}:{config['rabbitmq']['password']}@{config['rabbitmq']['url']}"


def get_mongodb_connection_url_openziti(config):
    return f"mongodb://{config['mongodb']['username']}:{config['mongodb']['password']}@{config['mongodb']['url']}.ziti-controller.private"


if os.environ.get("OPENZITI"):
    RABBITMQ_URL = get_rabbitmq_connection_url_openziti(ml_consumer_config)
    MONGODB_URI = get_mongodb_connection_url_openziti(ml_consumer_config)
else:
    RABBITMQ_URL = get_rabbitmq_connection_url(ml_consumer_config)
    MONGODB_URI = get_mongodb_connection_url(ml_consumer_config)

QUEUE_NAME = ml_consumer_config["rabbitmq"]["queue_name"]

DB_NAME = "object-detection"
COLLECTION_NAME = "results"

logging.basicConfig(level=logging.INFO)

# === TRACING SETUP ===
if os.environ.get("MANUAL_TRACING"):
    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.aio_pika import AioPikaInstrumentor

    # from opentelemetry.instrumentation.motor import MotorInstrumentor
    from opentelemetry.sdk.resources import SERVICE_NAME, Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    span_processor_endpoint = os.environ.get("OTEL_ENDPOINT")
    if not span_processor_endpoint:
        raise Exception("OTEL_ENDPOINT env variable is required for manual tracing")

    AioPikaInstrumentor().instrument()
    # MotorInstrumentor().instrument()

    trace_provider = TracerProvider(
        resource=Resource.create({SERVICE_NAME: "ml-consumer"})
    )
    trace_provider.add_span_processor(
        BatchSpanProcessor(OTLPSpanExporter(endpoint=span_processor_endpoint))
    )
    trace.set_tracer_provider(trace_provider)

    tracer = trace.get_tracer(__name__)
else:
    tracer = None  # Fallback if tracing is not enabled


async def process_message(message: aio_pika.IncomingMessage, collection):
    async with message.process():
        try:
            body = message.body.decode()
            data = json.loads(body)
            data["Endtime"] = time.time()

            if tracer:
                with tracer.start_as_current_span("process_message") as span:
                    span.set_attribute("process.name", current_process().name)
                    span.set_attribute(
                        "rabbitmq.message_id", message.message_id or "unknown"
                    )
                    span.set_attribute(
                        "rabbitmq.routing_key", message.routing_key or "unknown"
                    )
                    span.set_attribute(
                        "document.timestamp", data.get("Timestamp", "unknown")
                    )

                    logging.info(f"{current_process().name} received: {data}")
                    result = await collection.insert_one(data)
                    logging.info(
                        f"{current_process().name} inserted ID: {result.inserted_id}"
                    )
                    span.set_attribute("mongodb.inserted_id", str(result.inserted_id))
            else:
                logging.info(f"{current_process().name} received: {data}")
                result = await collection.insert_one(data)
                logging.info(
                    f"{current_process().name} inserted ID: {result.inserted_id}"
                )

        except Exception as e:
            logging.error(f"Error: {e}")
            if tracer:
                span.record_exception(e)


async def consume():
    if tracer:
        with tracer.start_as_current_span("consume_worker") as span:
            await _consume_logic(span)
    else:
        await _consume_logic(None)


async def _consume_logic(span):
    mongo_client = AsyncIOMotorClient(MONGODB_URI)
    collection = mongo_client[DB_NAME][COLLECTION_NAME]

    retries = 0
    delay = INITIAL_DELAY

    while retries < MAX_RETRIES:
        try:
            if span:
                span.add_event("Attempting RabbitMQ connection")
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
