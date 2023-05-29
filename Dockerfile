FROM docker.io/caddy:2.7-alpine

WORKDIR /app

COPY ./src .
COPY Caddyfile .

CMD ["caddy", "run"]