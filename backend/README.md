# Linguist AI Backend

## Quick start (local)

```powershell
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt
uvicorn main:app --reload
```

Swagger UI: `http://127.0.0.1:8000/docs`

## Docker

```powershell
docker build -t linguist-ai-backend:mock .
docker run --rm -p 8000:8000 linguist-ai-backend:mock
```

## Endpoints
For documentation, type: `http://127.0.0.1:8000/docs`.