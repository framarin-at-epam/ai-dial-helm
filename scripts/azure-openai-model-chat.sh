# curl -X POST https://foundryimagerecognitiondev.openai.azure.com/openai/v1/responses \
curl -X POST https://foundryimagerecognitiondev.services.ai.azure.com/openai/v1/deployments/gpt-4.1-nano/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $AZURE_OPENAI_AUTH_TOKEN" \
  -d '{
     "input": "This is a test."
    }'

#   "model": "gpt-4.1-nano",