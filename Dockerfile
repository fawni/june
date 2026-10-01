from oven/bun:1.4-alpine as bun

copy . /opt/app/
workdir /opt/app/

run bun i
RUN bunx tailwindcss \
    --config=tailwind.config.js \
    --input=./src/css/june.css \
    --output=./priv/static/css/june.css \
    --minify

from ghcr.io/gleam-lang/gleam:v1.18.1-elixir-alpine as builder

workdir /opt/app/
copy --from=bun /opt/app/ /opt/app/

run apk add --no-cache ca-certificates git && update-ca-certificates
run mix archive.install github hexpm/hex branch latest --force

run gleam deps download

run gleam export erlang-shipment \
  && mv ./build/erlang-shipment/ /opt/deploy/

from erlang:29-alpine

workdir /opt/deploy/
copy --from=builder /opt/deploy/ /opt/deploy/

arg docker_user=menhera
run addgroup -S $docker_user && adduser -S $docker_user -G $docker_user
user $docker_user

cmd ["/bin/sh", "/opt/deploy/entrypoint.sh", "run"]
