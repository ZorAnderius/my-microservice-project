FROM python:3.12-slim

RUN apt-get update && apt-get install -y libpq-dev gcc

WORKDIR /app

COPY pyproject.toml poetry.lock ./

RUN pip install --upgrade pip && pip install poetry

RUN poetry config virtualenvs.create false \
    && poetry install --only main --no-root --no-interaction --no-ansi

COPY . .

CMD [ "python", "manage.py", "runserver", "0.0.0.0:8000" ]
