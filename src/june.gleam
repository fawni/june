import gleam/erlang/process
import gleam/result
import glenvy/dotenv
import glenvy/env
import june/router
import mist
import wisp
import wisp/wisp_mist

pub fn main() {
  let _ = dotenv.load()
  wisp.configure_logger()

  let assert Ok(token) = env.get_string("JUNE_TOKEN")
  let port = result.unwrap(env.get_int("JUNE_PORT"), 6489)

  let assert Ok(_) =
    wisp_mist.handler(router.handle_request, token)
    |> mist.new
    |> mist.port(port)
    |> mist.start_http

  process.sleep_forever()
}
