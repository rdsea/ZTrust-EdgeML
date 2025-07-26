import pika
import json


# Connect to RabbitMQ server
connection = pika.BlockingConnection(
    pika.ConnectionParameters("rabbitmq.ziti-controller.private")
)
channel = connection.channel()

# Declare the queue to make sure it exists (optional but recommended)
channel.queue_declare(queue="object_detection_result", durable=True)

# The message you want to send

message = json.dumps({"Tri": "vo-dich-vo-doi"})
channel.basic_publish(exchange="", routing_key="object_detection_result", body=message)

# Publish the message to the queue
channel.basic_publish(
    exchange="",  # Default exchange, routes to queue by name
    routing_key="object_detection_result",  # Queue name
    body=message,
    properties=pika.BasicProperties(
        delivery_mode=2,  # Make message persistent
    ),
)

print("Sent message:", message)

# Close the connection
connection.close()
