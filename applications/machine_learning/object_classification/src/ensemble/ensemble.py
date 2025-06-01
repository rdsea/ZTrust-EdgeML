from __future__ import annotations

import asyncio
import json
import logging
import os
import sys
from contextlib import asynccontextmanager
from typing import Annotated

import aio_pika
import aiohttp
import ensemble_function
from fastapi import BackgroundTasks, FastAPI, Form, Request
from fastapi.responses import JSONResponse

if os.environ.get("MANUAL_TRACING"):
    span_processor_endpoint = os.environ.get("OTEL_ENDPOINT")
    if span_processor_endpoint is None:
        raise Exception("Manual debugging requires OTEL_ENDPOINT environment variable")

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.aio_pika import AioPikaInstrumentor
    from opentelemetry.instrumentation.aiohttp_client import AioHttpClientInstrumentor

    # from opentelemetry.sdk.metrics import MeterProvider
    # from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
    from opentelemetry.sdk.resources import SERVICE_NAME, Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    AioHttpClientInstrumentor().instrument()

    AioPikaInstrumentor().instrument()
    # Service name is required for most backends
    resource = Resource(attributes={SERVICE_NAME: "ensemble"})

    trace_provider = TracerProvider(resource=resource)
    processor = BatchSpanProcessor(OTLPSpanExporter(endpoint=span_processor_endpoint))
    trace_provider.add_span_processor(processor)
    trace.set_tracer_provider(trace_provider)

    tracer = trace.get_tracer(__name__)

SEND_TO_QUEUE = os.environ.get("SEND_TO_QUEUE", "false").lower() == "true"

current_directory = os.path.dirname(os.path.abspath(__file__))
util_directory = os.path.join(current_directory, "..", "util")
sys.path.append(util_directory)

# TODO: change utils to package that other service can reuse
import utils  # noqa: E402

config_lock = asyncio.Lock()  # Lock to control access to the global variable


config_file = "ensemble_service.yaml"
config = utils.load_config(file_path=config_file)

assert config is not None
logging.debug(f"Ensemble Service configuration: {config}")


def get_inference_service_url(ensemble_chosen: list[str]):
    return [f"http://{item.lower()}-service:5012/inference" for item in ensemble_chosen]


def get_inference_service_url_docker(ensemble_chosen: list[str]):
    return [f"http://{item.lower()}:5012/inference" for item in ensemble_chosen]


def get_inference_service_url_openziti(ensemble_chosen: list[str]):
    return [
        f"http://{item.lower()}.miniziti.private:5012/inference"
        for item in ensemble_chosen
    ]


def get_rabbitmq_connection_url(config: dict):
    rabbitmq_url = config["rabbitmq"]["url"]  # Example config
    username = config["rabbitmq"]["username"]
    password = config["rabbitmq"]["password"]
    return f"amqp://{username}:{password}@{rabbitmq_url}"


INFERENCE_SERVICE_URLS = get_inference_service_url(config["ensemble"])
if os.environ.get("DOCKER"):
    INFERENCE_SERVICE_URLS = get_inference_service_url_docker(config["ensemble"])

if os.environ.get("OPENZITI"):
    INFERENCE_SERVICE_URLS = get_inference_service_url_openziti(config["ensemble"])

RABBITMQ_URL = get_rabbitmq_connection_url(config)


@asynccontextmanager
async def lifespan(app: FastAPI):
    if SEND_TO_QUEUE:
        connection = await aio_pika.connect_robust(RABBITMQ_URL)
        channel = await connection.channel()
        queue_name = app.state.config["rabbitmq"]["queue_name"]
        await channel.declare_queue(queue_name, durable=True)

        app.state.rabbitmq_connection = connection
        app.state.rabbitmq_channel = channel

        yield  # Application runs during this period

        # Close RabbitMQ connection and channel at shutdown
        await channel.close()
        await connection.close()
    else:
        yield


app = FastAPI(lifespan=lifespan)
app.state.config = config


async def send_post_request(
    session: aiohttp.ClientSession, url: str, image_data: bytes, headers
):
    async with session.post(url, data=image_data, headers=headers) as response:
        return await response.json()  # Assuming the response is JSON


async def process_image_task(
    image_data: bytes, request_id: str, headers, timestamp: str
):
    chosen_ensemble_function = getattr(
        ensemble_function,
        app.state.config["aggregating"]["aggregating_func"]["func_name"],
    )
    logging.info(f"List service url: {INFERENCE_SERVICE_URLS}")

    if not INFERENCE_SERVICE_URLS:
        raise RuntimeError("No inference service url")

    async with aiohttp.ClientSession(trust_env=True) as session:
        tasks = [
            asyncio.create_task(send_post_request(session, url, image_data, headers))
            for url in INFERENCE_SERVICE_URLS
        ]
        done, _ = await asyncio.wait(tasks, return_when=asyncio.ALL_COMPLETED)

        results = []
        for task in done:
            results.append(await task)

        # Run ensemble function on the results
        final_result = chosen_ensemble_function(results, request_id)
        final_result["Timestamp"] = timestamp
        logging.info(f"Ensembled result: {final_result}")

        queue_name = app.state.config["rabbitmq"]["queue_name"]
        if SEND_TO_QUEUE:
            channel = app.state.rabbitmq_channel
            queue_name = app.state.config["rabbitmq"]["queue_name"]
            message_body = json.dumps(final_result).encode()
            message = aio_pika.Message(body=message_body)
            await channel.default_exchange.publish(message, routing_key=queue_name)
            logging.info(f"Sent result to RabbitMQ queue {queue_name}")


@app.post("/ensemble_service")
async def ensemble(
    request: Request,
    background_tasks: BackgroundTasks,
):
    try:
        image_bytes = await request.body()
        request_id = request.query_params["request_id"]
        headers = request.headers
        # logging.info(image_bytes)
        background_tasks.add_task(
            process_image_task, image_bytes, request_id, headers, headers["Timestamp"]
        )

        response = "Success to add image to Ensemble Service"
        return JSONResponse(content={"response": response}, status_code=200)
    except Exception as e:
        logging.exception(f"Error: {e}")
        return JSONResponse(content={"error": f"Error: {e}"}, status_code=500)


@app.post("/change_config")
async def change_requirement(configuration: Annotated[dict, Form()]):
    try:
        async with config_lock:
            app.state.config = configuration
            global INFERENCE_SERVICE_URLS
            INFERENCE_SERVICE_URLS = get_inference_service_url(
                app.state.config["ensemble"]
            )
            response = f"Change ensemble to: {configuration} successfully"
            return JSONResponse(content={"response": response}, status_code=200)
    except Exception as e:
        logging.exception(f"Error: {e}")
        return JSONResponse(content={"error": f"Error: {e}"}, status_code=500)


if os.environ.get("MANUAL_TRACING"):
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor

    FastAPIInstrumentor.instrument_app(app, exclude_spans=["send", "receive"])
