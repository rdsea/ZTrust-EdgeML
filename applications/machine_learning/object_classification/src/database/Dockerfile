FROM debian:stable-slim

WORKDIR /ml_consumer


COPY --from=ghcr.io/astral-sh/uv:0.4.3 /uv /bin/uv

COPY ./*.toml ./

RUN uv sync --compile-bytecode --no-cache

COPY ./*.py .

COPY ./*.yaml .

WORKDIR /ml_consumer

ENV PATH="/ml_consumer/.venv/bin:$PATH"

CMD ["python", "ml_consumer.py"]
