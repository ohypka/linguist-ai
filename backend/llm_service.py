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

def forbidden_words(topic: str, level: str, previous_target_words: list[str] | None = None):
    previous_target_words_text = ", ".join(previous_target_words or []) or "(none)"
    system_prompt = (
        "You are an English teacher assistant working as a backend for a language learning app. "
        "Your task is to generate a vocabulary challenge similar to the game \"Taboo\"."
        ""
        "Generate:"
        "1. \"target_word\": One English word that the user must describe."
        "2. \"forbidden_words\": A list of exactly 3 English words that are most commonly associated with the target word."
        ""
        "Difficulty rules based on CEFR level (A1, A2, B1, B2, C1, C2):"
        "- A1-A2: everyday concrete nouns/verbs."
        "- B1-B2: less frequent, more specific vocabulary."
        "- C1-C2: advanced, abstract, or domain-specific vocabulary."
        ""
        "Strict Rules:"
        "- All words must be in English."
        "- Do not use the target word itself as a forbidden word."
        "- Avoid repeating any target word from the provided previous target words list."
        "- If the topic is narrow, still choose a fresh and natural alternative instead of repeating a recent word."
        "- The forbidden words must keep the round playable: avoid trap combinations where the target becomes nearly impossible to describe."
        "- Do not use forbidden words that are overly generic, definitional core words, or near-overlaps that remove all obvious ways to explain the target."
        "- Prefer related clues that make the task challenging but still solvable by paraphrasing."
        "- If a target would force impossible forbidden words, choose a simpler or more describable target instead."
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
        temperature=1.1,
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": (
                    "Generate a target word and forbidden words for the topic: "
                    + topic
                    + ". CEFR level: "
                    + level
                    + "\nPrevious target words to avoid: "
                    + previous_target_words_text
                ),
            }
        ]
    )
    words = json.loads(response.choices[0].message.content)
    return words


def forbidden_words_eval(description: str, forbidden_words: list[str]):
    system_prompt = (
        "You are an expert linguist and vocabulary AI. "
        "The user will provide a description, definition, or hints about a specific English word. "
        "Your task is to guess that exact English word based on the description."
        "You must respond STRICTLY in valid JSON format containing exactly two keys: \"word\" and \"confidence\". "
        "Do not output any markdown formatting, explanations, or additional text outside the JSON object."
        "Do NOT guess any word from the forbidden list. If the best guess is forbidden, pick the closest allowed alternative."
        "Expected JSON format:"
        "{"
        "\"word\": \"the single English word you guessed\","
        "\"confidence\": \"your confidence level from 0 to 100\""
        "}"
    )
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": "Description: "
                + description
                + "\nForbidden words: "
                + ", ".join(forbidden_words),
            }
        ]
    )
    evaluation = json.loads(response.choices[0].message.content)
    word = evaluation["word"]
    confidence = int(evaluation["confidence"])
    return word, confidence


def forbidden_words_match(target_word: str, description: str) -> dict[str, object]:
    system_prompt = (
        "You are an expert evaluator in a Taboo-like vocabulary game. "
        "Decide if the user's description refers to the target word. "
        "Allow close synonyms and paraphrases as a correct match, even if the exact word is not used. "
        "Return ONLY JSON with keys: \"is_match\" (true/false), \"confidence\" (0-100), \"reason\" (short)."
        ""
        "JSON format:"
        "{"
        "\"is_match\": true,"
        "\"confidence\": 85,"
        "\"reason\": \"short reason\""
        "}"
    )
    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": "Target word: "
                + target_word
                + "\nDescription: "
                + description,
            },
        ],
    )
    return json.loads(response.choices[0].message.content)

def generate_deck(count: int, topic: str, level: str = 'B1'):
    system_prompt=(
        "Jesteś doświadczonym lektorem języka angielskiego, który pomaga polskim uczniom w nauce, wyłapując i tłumacząc typowe błędy gramatyczne, leksykalne oraz kalki językowe."
        "Twoim zadaniem jest wygenerowanie listy zdań w języku angielskim o zróżnicowanym poziomie trudności. "
        "Część zdań powinna być w 100% poprawna, druga część powinna zawierać jeden błąd, którego powszechność niech będzie uzależniona od poziomu trudności zdania."
        "Upewnij się, obie części nie są równomiernie reprezentowane, ale mniejsza stanowi przynajmniej 20% całości."
        "Dla zdań poprawnych NIE zwracaj pola \"explanation\". Dla zdań błędnych zwracaj pole \"explanation\" i wyjaśnij konkretny błąd."
        "Upewnij się o absolutnej poprawności wyjaśnień dla zdań błędnych."
        "Wynik musisz zwrócić WYŁĄCZNIE w formacie JSON, jako listę obiektów. "
        "Nie dodawaj absolutnie żadnego tekstu, powitań ani komentarzy poza samym kodem JSON. "
        "Każdy obiekt musi mieć dokładnie taką strukturę:"
        "{"
        "\"text\": \"[Tutaj zdanie po angielsku]\","
        "\"is_correct\": [true lub false],"
        "\"explanation\": \"[Zwięzłe, edukacyjne wyjaśnienie po polsku dla zdań błędnych]\""
        "}"
        "Oto przykłady oczekiwanego formatu i stylu:"
        "["
        "{\"text\": \"She don't like apples.\", \"is_correct\": false, \"explanation\": \"Powinno być 'doesn't', ponieważ 'she' to trzecia osoba liczby pojedynczej.\"},"
        "{\"text\": \"I have been working here for 5 years.\", \"is_correct\": true},"
        "{\"text\": \"Let's discuss about the project.\", \"is_correct\": false, \"explanation\": \"Czasownik 'discuss' nie wymaga przyimka 'about'.\"}"
        "]"
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Wygeneruj '{count}' nowych, unikalnych przykładów w ramach tematu '{topic}'. Poziom CEFR: {level}."},
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
        "1. Długość: maksymalnie 2-3 zdania."
        "2. Ton zależy od wyniku: 80-100% (entuzjazm i pochwała), 50-79% (docenienie starań i zachęta), poniżej 50% (wsparcie i motywacja, bez surowej krytyki)."
        "3. Feedback ma byc ogolny: NIE cytuj ani nie streszczaj konkretnych zdan z gry."
        "4. Wartość edukacyjna: zamiast przykladow, podaj jedna ogolna wskazowke (np. o czasach, przyimkach, szyku)."
        "5. Jeśli lista \"Błędne odpowiedzi\" jest pusta, po prostu serdecznie pogratuluj."
        "6. Zwracaj się bezpośrednio do użytkownika na \"Ty\"."
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

def quick_reactions(topic: str, recent_prompts: list[str] | None = None, level: str = 'B1'):
    recent_prompt_text = "\n".join(f"- {prompt}" for prompt in (recent_prompts or []))
    system_prompt = (
        "You are an unpredictable, witty, and slightly chaotic NPC in a fast-paced English language learning minigame. "
        "Your task is to generate exactly ONE engaging sentence that will force the player to react quickly and spontaneously. "
        "The sentence must feel like something the player wants to answer, challenge, defend against, or bounce off immediately. "
        "The sentence should loosely fit the lesson topic so the round feels coherent. "
        "Avoid repeating the tone, setup, or core idea of recent prompts. "
        "Prefer a different archetype from the previous round."
        ""
        "The sentence must fit one of these broad reaction-first archetypes, but do not reuse the same archetype as the recent prompts:"
        "1. Absurd challenge"
        "2. Awkward accusation"
        "3. Strange claim"
        "4. Slightly snarky complaint"
        "5. Unexpected drama"
        "Rules & Constraints:"
        "- Output ONLY the sentence. No introductory text, no explanations, no quotation marks."
        "- The language must be modern, conversational, and grammatically perfect."
        "- Keep the vocabulary accessible for an intermediate English learner (B1-B2 level), but the context should be surprising."
        "- The length should be between 7 and 15 words."
        "- Do not use overly complex grammar structures; the goal is quick comprehension."
        "- Keep it family-friendly (no profanity, violence, or highly sensitive topics)."
        "- Prefer a line that triggers a direct comeback, not a standalone joke or trivia fact."
    )

    response = client.chat.completions.create(
        model=model,
        messages=[
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": "Topic: " + topic + "\nCEFR level: " + level + "\nRecent prompts:\n" + (recent_prompt_text or "(none)") + "\nGenerate the sentence now.",
            }
        ]
    )

    sentence = response.choices[0].message.content
    return sentence


def quick_reactions_eval(topic: str, sentence: str, player_response: str):
    system_prompt = (
        "You are an expert evaluator in a fast-paced English language learning minigame. "
        "The player has just responded to a surprising sentence. "
        "The current lesson topic is part of the context, so judge the response as if it belongs to that theme. "
        "Your task is to evaluate the player's response based on three criteria: Relevance, Creativity, and Language Quality."
        "After that, provide one concise, natural sentence of feedback in Polish, addressed directly to the player."
        ""
        "Criteria Definitions:"
        "1. Relevance: How well does the player's response directly address or relate to the original sentence? (0-100)"
        "2. Creativity: How original, imaginative, or unexpected is the player's response? (0-100)"
        "3. Language Quality: How grammatically correct and fluent is the player's response? (0-100)"
        ""
        "Rules & Constraints:"
        "- Provide a score from 0 to 100 for each criterion, where 0 is the lowest and 100 is the highest."
        "- Be strict with low-effort answers like 'yes', 'no', 'yes, I know', 'I know', 'maybe'. These should usually get very low creativity and low overall value."
        "- Creative answers that are slightly indirect but still clearly react to the prompt can score well."
        "- The feedback HAS to be in Polish, no exceptions."
        "- Do not mention the model, AI, LLM, scoring internals, JSON, or evaluation process in the feedback."
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
            {"role": "user", "content": "Topic: " + topic + "\nOriginal sentence: " + sentence + "\nPlayer's response: " + player_response}
        ]
    )

    evaluation = json.loads(response.choices[0].message.content)
    return evaluation


if __name__ == "__main__":
    f = generate_deck(10, "General English")
    print(f)
