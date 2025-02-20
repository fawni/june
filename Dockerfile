from oven/bun:1.2-alpine as bun

copy . /opt/app/
workdir /opt/app/

run bun i
run apk add curl
run curl -sLO https://github.com/tailwindlabs/tailwindcss/releases/download/v3.4.15/tailwindcss-linux-x64
run chmod +x tailwindcss-linux-x64
run mv tailwindcss-linux-x64 tailwindcss
run ./tailwindcss --config=tailwind.config.js --input=./src/css/june.css --output=./priv/static/css/june.css --minify

from ghcr.io/gleam-lang/gleam:v1.8.1-elixir-alpine as builder

workdir /opt/app/
copy --from=bun /opt/app/ /opt/app/

run mix local.hex --force 

run gleam deps download 

run gleam export erlang-shipment \
  && mv ./build/erlang-shipment/ /opt/deploy/

from erlang:27-alpine

workdir /opt/deploy/
copy --from=builder /opt/deploy/ /opt/deploy/

arg docker_user=menhera
run addgroup -S $docker_user && adduser -S $docker_user -G $docker_user
user $docker_user

cmd ["/opt/deploy/entrypoint.sh", "run"]
