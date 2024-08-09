from ghcr.io/gleam-lang/gleam:v1.4.1-elixir-alpine

copy . /opt/app/

workdir /opt/app/
run mix local.hex --force 

run gleam deps download \
  && gleam run -m tailwind/install \
  && gleam run -m tailwind/run 

run gleam export erlang-shipment \
  && mv ./build/erlang-shipment/ /opt/deploy/ 

workdir /opt/deploy/

arg docker_user=menhera
run addgroup -S $docker_user && adduser -S $docker_user -G $docker_user
user $docker_user

cmd ["/opt/deploy/entrypoint.sh", "run"]
