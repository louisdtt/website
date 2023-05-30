FROM docker.io/caddy:2.7-alpine

WORKDIR /src

EXPOSE 443

COPY ./src/* .
COPY Caddyfile .

CMD ["caddy", "run"]