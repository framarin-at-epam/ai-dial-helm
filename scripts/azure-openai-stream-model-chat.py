import asyncio
import os
import json

from openai import AsyncOpenAI

# gets the API Key from environment variable AZURE_OPENAI_API_KEY
endpoint = os.getenv(
    "AZURE_OPENAI_BASE_URL",
    "https://FoundryImageRecognitionDev.services.ai.azure.com/openai/v1",
)
deployment_name = os.getenv("AZURE_OPENAI_DEPLOYMENT", "gpt-4.1-nano")
api_key = os.getenv(
    "AZURE_OPENAI_API_KEY",
    "<azure_foundry_api_key>",
)

if not api_key:
    raise RuntimeError("Set the AZURE_OPENAI_API_KEY environment variable before running this script.")


async def main() -> None:
    client = AsyncOpenAI(
        base_url=endpoint,
        api_key=api_key,
    )

    stream = await client.responses.create(
        model=deployment_name,
        input="How to enjoy a Clojure experience in all platforms and frameworks: scripting, jvm, native, etc.?",
        stream=True,
    )

    async for event in stream:
        if event.type == "response.output_text.delta":
            print(event.delta, end="", flush=True)
        #print(event.to_json(indent=2))


asyncio.run(main())