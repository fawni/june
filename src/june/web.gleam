import wisp

pub fn middleware(
  req: wisp.Request,
  handle_request: fn(wisp.Request) -> wisp.Response,
) -> wisp.Response {
  let req = wisp.method_override(req)
  use <- wisp.log_request(req)
  use <- wisp.rescue_crashes
  use <- wisp.serve_static(req, under: "/public", from: static_directory())
  use req <- wisp.handle_head(req)

  handle_request(req)
}

pub fn static_directory() -> String {
  let assert Ok(dir) = wisp.priv_directory("june")
  dir <> "/static"
}
