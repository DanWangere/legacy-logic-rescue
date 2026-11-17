import json
import os
import time
from uuid import uuid4
from datetime import datetime, timezone

from dotenv import load_dotenv
from azure.eventhub import EventHubProducerClient, EventData

load_dotenv(".env.eventstream")

connection_string = os.getenv(
    "LLR_EVENTHUB_CONNECTION_STRING"
)

if not connection_string:
    raise ValueError("Event Hub connection string is missing")

with EventHubProducerClient.from_connection_string(
    conn_str=connection_string
) as producer:

    for batch_number in range(6):
        batch = producer.create_batch()

        for i in range(5):
            sequence = batch_number * 5 + i

            status = (
                "FAILED"
                if sequence % 11 == 0
                else "SUCCEEDED"
            )

            event = {
                "event_id": str(uuid4()),
                "event_time": datetime.now(
                    timezone.utc
                ).isoformat().replace("+00:00", "Z"),
                "pipeline_name": "pl_llr_refresh_gold",
                "run_id": "simulation-run-001",
                "stage": "gold_validation",
                "status": status,
                "duration_ms": 800 + sequence * 50,
                "records_processed": 23,
                "is_simulated": True,
                "message": (
                    "Simulated validation failure"
                    if status == "FAILED"
                    else "Simulated validation success"
                )
            }

            batch.add(EventData(json.dumps(event)))

        producer.send_batch(batch)

        print(f"Sent batch {batch_number + 1}/6")
        time.sleep(3)

print("Successfully sent 30 simulated events.")
