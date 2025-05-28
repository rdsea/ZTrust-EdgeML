import asyncio
import json
from collections import Counter
from datetime import datetime
from statistics import mean, stdev

import numpy as np  # for percentile calculation
from ml_consumer import MONGODB_URI
from motor.motor_asyncio import AsyncIOMotorClient

mongo_client = AsyncIOMotorClient(MONGODB_URI)
db = mongo_client["object-detection"]
collection = db["results"]


async def get_latest_documents_and_times(
    limit=1000, output_file="results_summary.json"
):
    cursor = collection.find(sort=[("_id", -1)], limit=limit)
    documents = await cursor.to_list(length=limit)

    records = []
    times = []
    request_ids = []

    for i, doc in enumerate(documents):
        try:
            request_id = doc["request_id"]
            request_ids.append(request_id)

            request_time = float(doc["Timestamp"])
            insert_time = doc["Endtime"]
            total_time = insert_time - request_time
            times.append(total_time)

            record = {
                "document_index": i + 1,
                "request_id": request_id,
                "request_time": datetime.fromtimestamp(request_time).isoformat(),
                "insert_time": datetime.fromtimestamp(insert_time).isoformat(),
                "total_time_seconds": total_time,
            }
            records.append(record)

        except (KeyError, ValueError, TypeError) as e:
            records.append({"document_index": i + 1, "error": str(e), "raw_doc": doc})

    summary = {}
    if times:
        p99 = np.percentile(times, 99)
        summary = {
            "documents_processed": len(times),
            "average_time_seconds": mean(times),
            "min_time_seconds": min(times),
            "max_time_seconds": max(times),
            "stddev_time_seconds": stdev(times) if len(times) > 1 else 0,
            "p99_time_seconds": p99,
        }

    request_id_counts = Counter(request_ids)
    duplicates = {rid: count for rid, count in request_id_counts.items() if count > 1}

    output = {
        "records": records,
        "summary": summary,
        "duplicates": duplicates,
    }

    # Write to JSON file
    with open(output_file, "w") as f:
        json.dump(output, f, indent=4)

    print(f"Processed {len(records)} records.")
    print(f"Summary saved to {output_file}")


if __name__ == "__main__":

    async def main():
        await get_latest_documents_and_times(limit=10000)

    asyncio.run(main())
