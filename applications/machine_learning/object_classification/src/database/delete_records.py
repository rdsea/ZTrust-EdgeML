import asyncio

from ml_consumer import MONGODB_URI
from motor.motor_asyncio import AsyncIOMotorClient

mongo_client = AsyncIOMotorClient(MONGODB_URI)
db = mongo_client["object-detection"]
collection = db["results"]


async def delete_all_documents():
    result = await collection.delete_many({})
    print(f"Deleted {result.deleted_count} documents.")


if __name__ == "__main__":
    asyncio.run(delete_all_documents())
