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

def generate_deck(count : int, topic : str):
    system_prompt=(
        "Jesteś doświadczonym lektorem języka angielskiego, który pomaga polskim uczniom w nauce, wyłapując i tłumacząc typowe błędy gramatyczne, leksykalne oraz kalki językowe."
        "Twoim zadaniem jest wygenerowanie listy zdań w języku angielskim o zróżnicowanym poziomie trudności. "
        "Połowa zdań powinna być w 100% poprawna, a druga połowa powinna zawierać jeden, powszechny błąd."
        "Upewnij się o absolutnej poprawności wyjaśnień."
        "Wynik musisz zwrócić WYŁĄCZNIE w formacie JSON, jako listę obiektów. "
        "Nie dodawaj absolutnie żadnego tekstu, powitań ani komentarzy poza samym kodem JSON. "
        "Każdy obiekt musi mieć dokładnie taką strukturę:"
        "{"
        "\"text\": \"[Tutaj zdanie po angielsku]\","
        "\"is_correct\": [true lub false],"
        "\"explanation\": \"[Zwięzłe, edukacyjne wyjaśnienie po polsku, wskazujące na konkretną regułę gramatyczną lub poprawne użycie]\""
        "}"
        "Oto przykłady oczekiwanego formatu i stylu:"
        "["
        "{\"text\": \"She don't like apples.\", \"is_correct\": false, \"explanation\": \"Powinno być 'doesn't', ponieważ 'she' to trzecia osoba liczby pojedynczej.\"},"
        "{\"text\": \"I have been working here for 5 years.\", \"is_correct\": true, \"explanation\": \"Poprawne użycie Present Perfect Continuous.\"},"
        "{\"text\": \"Let's discuss about the project.\", \"is_correct\": false, \"explanation\": \"Czasownik 'discuss' nie wymaga przyimka 'about'.\"}"
        "]"
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Wygeneruj '{count}' nowych, unikalnych przykładów w ramach tematu '{topic}'."},
        ]
    )

    a = json.loads(response.choices[0].message.content)
    return a

if __name__ == "__main__":
    f = generate_deck(10, "General English")
    print(f)