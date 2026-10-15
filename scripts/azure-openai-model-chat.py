from openai import OpenAI
 
endpoint = "https://FoundryImageRecognitionDev.services.ai.azure.com/openai/v1"
#endpoint = "https://foundryimagerecognitiondev.services.ai.azure.com/openai/v1"
#deployment_name = "gpt-5.4-pro"
deployment_name = "gpt-4.1-nano"
api_key = "<azure_foundry_api_key>"
 
client = OpenAI(
    base_url=endpoint,
    api_key=api_key
)

response = client.responses.create(
    model=deployment_name,
    input="Name a capital for a imaginary country called Whateverland?",
)
 
print(client.base_url)

print(f"answer: {response.output[0]}")
