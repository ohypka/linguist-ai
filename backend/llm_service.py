import json

from openai import OpenAI
from dotenv import load_dotenv
import os

load_dotenv()
client = OpenAI(
    api_key=os.getenv("OPENAI_API_KEY"),
    base_url="https://services.clarin-pl.eu/api/v1/oapi"
)
model = "gpt-4o-mini"

def forbidden_words(description : str):
    system_prompt=("You are an expert linguist and vocabulary AI. "
                   "The user will provide a description, definition, or hints about a specific English word. "
                   "Your task is to guess that exact English word based on the description."
                   "You must respond STRICTLY in valid JSON format containing exactly two keys: \"word\" and \"confidence\". "
                   "Do not output any markdown formatting, explanations, or additional text outside the JSON object."
                   "Expected JSON format:"
                   "{"
                   "\"word\": \"the single English word you guessed\","
                   "\"confidence\": \"your confidence level from 0 to 100\""
                   "}")
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": description}
        ]
    )
    print(response.choices[0].message.content)
    a = json.loads(response.choices[0].message.content)
    word = a["word"]
    confidence = int(a["confidence"])
    return word, confidence

if __name__ == "__main__":
    description = "A person who shares knowledge in an education facility for young people, also grades them."
    w, c = forbidden_words(description)
    print(w + ", " + str(c))