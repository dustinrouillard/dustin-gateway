FROM elixir:1.12-alpine

ENV MIX_ENV=prod

WORKDIR /app

COPY .git .git
COPY lib lib
COPY config config

COPY mix.exs .
COPY mix.lock .

RUN apk add openssl git openssh

RUN git config --unset 'http.https://github.com/.extraheader'

RUN mix local.rebar --force \
    && mix local.hex --force \
    && mix deps.get \
    && mix compile

ENTRYPOINT [ "sh", "-c", "elixir --name gateway@${POD_IP} --cookie dstn --no-halt -S mix" ]