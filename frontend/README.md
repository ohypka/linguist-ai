# Linguist AI - Frontend

Flutter frontend for **Linguist AI**, an English learning app based on short AI-supported language games.

The frontend communicates with a FastAPI backend through REST API.

## Features

- user name, lesson topic and CEFR level selection,
- guest mode based on a local `device_id`,
- **Grammar Cards** - checking if sentences are correct or incorrect,
- **Forbidden Words** - describing a word without using forbidden words,
- **Quick Reactions** - fast spoken answers to short prompts,
- **Speaking Mode** - speech-to-text speaking practice,
- leaderboard,
- game history.

## Android requirements

The app requires internet and microphone access.

## Backend connection

The backend should run locally on port `8000`.

Frontend backend URLs:

```text
Flutter Web:      http://127.0.0.1:8000
Android emulator: http://10.0.2.2:8000
```

## Running the frontend

Install dependencies:

```bash
flutter pub get
```

Run the app:

```bash
flutter run
```

Run static analysis:

```bash
flutter analyze
```

Run tests:

```bash
flutter test
```

## Project structure

```text
lib/
├── app.dart
├── main.dart
├── screens/
│   ├── topic/
│   ├── home/
│   ├── games/
│   ├── speaking/
│   ├── leaderboard/
│   └── history/
├── services/
│   ├── api_service.dart
│   └── speech_service.dart
└── widgets/
```