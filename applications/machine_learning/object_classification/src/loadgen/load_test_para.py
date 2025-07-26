from locust import HttpUser, between, task, events
import logging
import os
import random
import time
from pathlib import Path


class ImageUploadUser(HttpUser):
    wait_time = between(1, 1)

    def on_start(self):
        # Get custom args
        self.ds_path = Path(self.environment.parsed_options.ds_path)
        self.device_id = self.environment.parsed_options.device_id

        try:
            files = os.listdir(self.ds_path)
            self.jpeg_images_list = [
                file for file in files if file.lower().endswith(".jpeg")
            ]
        except Exception as e:
            logging.error(f"Failed to list dataset directory: {e}")
            self.jpeg_images_list = []

    @task
    def upload_image(self):
        if not self.jpeg_images_list:
            logging.warning("No JPEG images found, skipping task.")
            return

        try:
            random_image = random.choice(self.jpeg_images_list)
            image_path = os.path.join(self.ds_path, random_image)

            root, _ = os.path.splitext(image_path)
            _, synset_id = os.path.basename(root).rsplit("_", 1)

            with open(image_path, "rb") as img_file:
                img_data = img_file.read()

            files = {
                "file": ("random_image.jpeg", img_data, "image/jpeg"),
                "device_id": (None, self.device_id),
            }

            start_time = time.time()
            headers = {
                "Timestamp": str(start_time),
            }
            with self.client.post(
                "/preprocessing", files=files, catch_response=True, headers=headers
            ) as response:
                response_time = (time.time() - start_time) * 1000
                if response.status_code == 200:
                    json_response = response.json()
                    print(json_response, synset_id, response_time)
                    response.success()
                else:
                    response.failure(
                        f"Failed with {response.status_code}: {response.text}"
                    )

        except Exception as e:
            logging.exception(f"Exception during upload: {e}")


# Register custom arguments
def add_custom_arguments(parser):
    parser.add_argument(
        "--ds-path",
        type=str,
        env_var="LOCUST_DS_PATH",
        default="./image/",
        help="Path to dataset folder containing JPEG images",
    )
    parser.add_argument(
        "--device-id",
        type=str,
        env_var="LOCUST_DEVICE_ID",
        default="drone_1",
        help="Device ID to send with each request",
    )


events.init_command_line_parser.add_listener(add_custom_arguments)
