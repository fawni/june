from oven/bun:1.2-alpine as bun

copy . /opt/app/
workdir /opt/app/

run bun i \
  && bun i -g @tailwindcss/cli

from ghcr.io/gleam-lang/gleam:v1.8.1-elixir-alpine as builder

workdir /opt/app/
copy --from=bun /opt/app/ /opt/app/

run mix local.hex --force 

run gleam deps download \
  && gleam run -m tailwind/run

run gleam export erlang-shipment \
  && mv ./build/erlang-shipment/ /opt/deploy/

from erlang:27-alpine

workdir /opt/deploy/
copy --from=builder /opt/deploy/ /opt/deploy/

arg docker_user=menhera
run addgroup -S $docker_user && adduser -S $docker_user -G $docker_user
user $docker_user

cmd ["/opt/deploy/entrypoint.sh", "run"]
