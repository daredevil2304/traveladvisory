import os
import requests
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GROQ_API_KEY")
model = os.getenv("GROQ_MODEL")

print("Key loaded:", bool(api_key))
print("Model:", model)

response = requests.post(
    "https://api.groq.com/openai/v1/chat/completions",
    headers={
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    },
    json={
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": "Reply with exactly: OK"
            }
        ],
        "temperature": 0.2,
    },
    timeout=30,
)

print("HTTP status:", response.status_code)
print("Response:")

try:
    data = response.json()
    if response.ok:
        print(data["choices"][0]["message"]["content"])
    else:
        print(data)
except Exception:
    print(response.text)
