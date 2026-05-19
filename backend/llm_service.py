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

def forbidden_words(topic : str):
    system_prompt = ("You are an English teacher assistant working as a backend for a language learning app. "
                     "Your task is to generate a vocabulary challenge similar to the game \"Taboo\"."
                     ""
                     "Generate:"
                     "1. \"target_word\": One English word that the user must describe."
                     "2. \"forbidden_words\": A list of exactly 3 English words that are most commonly associated with the target word."
                     ""
                     "Strict Rules:"
                     "- All words must be in English."
                     "- Return ONLY a raw JSON object. Do not include markdown code blocks or any conversational text."
                     ""
                     "Format your response exactly like this:"
                     "{"
                     "\"target_word\": \"example\","
                     "\"forbidden_words\": [\"first\", \"second\", \"third\"]"
                     "}"
                     )
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Generate a target word and forbidden words for the topic: " + topic}
        ]
    )
    words = json.loads(response.choices[0].message.content)
    return words


def forbidden_words_eval(description : str):
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
    evaluation = json.loads(response.choices[0].message.content)
    word = evaluation["word"]
    confidence = int(evaluation["confidence"])
    return word, confidence

def generate_deck(count : int, topic : str):
    system_prompt=(
        "Jesteś doświadczonym lektorem języka angielskiego, który pomaga polskim uczniom w nauce, wyłapując i tłumacząc typowe błędy gramatyczne, leksykalne oraz kalki językowe."
        "Twoim zadaniem jest wygenerowanie listy zdań w języku angielskim o zróżnicowanym poziomie trudności. "
        "Część zdań powinna być w 100% poprawna, druga część powinna zawierać jeden błąd, którego powszechność niech będzie uzależniona od poziomu trudności zdania."
        "Upewnij się, obie części nie są równomiernie reprezentowane, ale mniejsza stanowi przynajmniej 20% całości."
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

    cards = json.loads(response.choices[0].message.content)
    return cards

def cards_feedback(accuracy, mistakes, successes):
    system_prompt = (
        "Jesteś wspierającym lektorem języka angielskiego w aplikacji do nauki. "
        "Użytkownik skończył minigrę oceniającą poprawność gramatyczną zdań. "
        "Wygeneruj krótki, spersonalizowany feedback w języku polskim."
        "Podstawą będzie poprawność odpowiedzi (accuracy) w procentach; lista zdań, na które użytkownik odpowiedział niepoprawnie oraz lista zdań, na które użytkownik odpowiedział poprawnie."
        ""
        "Wytyczne:"
        "1. Długość: maksymalnie 3-4 zdania."
        "2. Ton zależy od wyniku: 80-100% (entuzjazm i pochwała), 50-79% (docenienie starań i zachęta), poniżej 50% (wsparcie i motywacja, bez surowej krytyki)."
        "3. Wartość edukacyjna: Jeśli na liście \"Błędne odpowiedzi\" są zdania, wybierz TYLKO JEDNO z nich i w jednym zdaniu krótko wyjaśnij regułę gramatyczną, którą użytkownik złamał (podaj poprawną formę)."
        "4. Jeśli lista \"Błędne odpowiedzi\" jest pusta, po prostu serdecznie pogratuluj."
        "5. Zwracaj się bezpośrednio do użytkownika na \"Ty\"."
    )
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Poprawność: {accuracy}, Błędne odpowiedzi: {mistakes}, Poprawne odpowiedzi: {successes}"}
        ]
    )

    feedback = response.choices[0].message.content
    return feedback

def quick_reactions():
    system_prompt = (
        "You are an unpredictable, witty, and slightly chaotic NPC in a fast-paced English language learning minigame. "
        "Your task is to generate exactly ONE engaging sentence that will force the player to react quickly and spontaneously."
        ""
        "The sentence must fit into one of the following categories, chosen at random:"
        "1. Absurd & Surreal (e.g., \"Excuse me, you just stepped on my invisible dog!\")"
        "2. Mildly Confrontational / Awkward (e.g., \"Why are you wearing pajamas to a business meeting?\")"
        "3. Random / Bizarre Trivia (e.g., \"Did you know that penguins have knees?\")"
        "4. Mildly Insulting / Funny Critique (e.g., \"Your laugh sounds like a broken printer.\")"
        "5. Unexpected Drama (e.g., \"I just heard you got rejected by three places today.\")"
        "Rules & Constraints:"
        "- Output ONLY the sentence. No introductory text, no explanations, no quotation marks."
        "- The language must be modern, conversational, and grammatically perfect."
        "- Keep the vocabulary accessible for an intermediate English learner (B1-B2 level), but the context should be surprising."
        "- The length should be between 7 and 15 words."
        "- Do not use overly complex grammar structures; the goal is quick comprehension."
        "- Keep it family-friendly (no profanity, violence, or highly sensitive topics)."
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Generate the sentence now."}
        ]
    )

    sentence = response.choices[0].message.content
    return sentence


def quick_reactions_eval(sentence : str, player_response : str):
    system_prompt = (
        "You are an expert evaluator in a fast-paced English language learning minigame. "
        "The player has just responded to a surprising sentence. "
        "Your task is to evaluate the player's response based on three criteria: Relevance, Creativity, and Language Quality."
        "After that, provide a one sentence feedback in Polish based on your evaluation."
        ""
        "Criteria Definitions:"
        "1. Relevance: How well does the player's response directly address or relate to the original sentence? (0-100)"
        "2. Creativity: How original, imaginative, or unexpected is the player's response? (0-100)"
        "3. Language Quality: How grammatically correct and fluent is the player's response? (0-100)"
        ""
        "Rules & Constraints:"
        "- Provide a score from 0 to 100 for each criterion, where 0 is the lowest and 100 is the highest."
        "- The feedback HAS to be in Polish, no exceptions."
        "- Output ONLY a JSON object with the three scores and a single sentence feedback. No explanations, no additional text."
        "- The JSON format must be exactly as follows:"
        "{"
        "\"relevance\": [score],"
        "\"creativity\": [score],"
        "\"language_quality\": [score],"
        "\"feedback\": [text]"
        "}"
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": "Original sentence: " + sentence + "\nPlayer's response: " + player_response}
        ]
    )

    evaluation = json.loads(response.choices[0].message.content)
    return evaluation


if __name__ == "__main__":
    f = generate_deck(10, "General English")
    print(f)