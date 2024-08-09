import filepath
import gleam/bool
import gleam/http
import gleam/list
import gleam/result
import gleam/string_builder
import glenvy/env
import june/blake2b
import june/pages
import june/web
import simplifile
import snag
import wisp

fn data_path() {
  case env.get_string("HOME") {
    Ok(home) -> home <> "/.local/share/june/"
    _ -> "./"
  }
}

pub fn handle_request(req: wisp.Request) -> wisp.Response {
  use req <- web.middleware(req)

  case wisp.path_segments(req) {
    [] -> handle_root(req)
    _ -> handle_retrieve_file(req)
  }
}

fn handle_root(req: wisp.Request) -> wisp.Response {
  case req.method {
    http.Get -> pages.home()
    http.Post -> handle_form_submission(req)
    _ -> wisp.method_not_allowed(allowed: [http.Get, http.Post])
  }
}

fn handle_form_submission(req: wisp.Request) -> wisp.Response {
  use formdata <- wisp.require_form(req)
  let token = wisp.get_secret_key_base(req)

  case upload_file(token, formdata) {
    Ok(name) -> {
      wisp.created()
      |> wisp.html_body(name |> string_builder.from_string)
    }
    Error(err) -> {
      err
      |> snag.line_print
      |> string_builder.from_string
      |> wisp.html_response(400)
    }
  }
}

fn upload_file(
  june_token: String,
  formdata: wisp.FormData,
) -> snag.Result(String) {
  case list.key_find(formdata.values, "token") {
    Ok(token) if token == june_token -> {
      use file <- result.try(
        list.key_find(formdata.files, "file")
        |> as_snag("No file provided"),
      )

      use file_bits <- result.try(
        simplifile.read_bits(from: file.path)
        |> as_snag("simplifile: Could not read file bits"),
      )
      let hashed = blake2b.hash(file_bits)
      let file_name = case filepath.extension(file.file_name) {
        Ok(ext) -> hashed <> "." <> ext
        Error(_) -> hashed
      }

      use _ <- result.try(
        simplifile.create_directory_all(data_path())
        |> as_snag("simplifile: Could not create june data directory"),
      )

      use _ <- result.try(
        simplifile.copy_file(at: file.path, to: data_path() <> file_name)
        |> as_snag("simplifile: Could not copy file to june data directory"),
      )
      wisp.log_info("File uploaded to " <> data_path() <> file_name)

      Ok(file_name)
    }
    Ok(invalid) if invalid != "" -> {
      wisp.log_warning(
        "User attempted to upload with an invalid token: \"" <> invalid <> "\"",
      )
      snag.error("Invalid token: \"" <> invalid <> "\"")
    }
    _ -> {
      wisp.log_warning("User attempted to upload without a token")
      snag.error("Missing token")
    }
  }
}

fn handle_retrieve_file(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Get)

  case retrieve_file(req) {
    Ok(path) -> wisp.ok() |> wisp.set_body(wisp.File(path: path))
    Error(err) ->
      err
      |> snag.line_print
      |> pages.not_found
  }
}

fn retrieve_file(req: wisp.Request) -> snag.Result(String) {
  use name <- result.try(
    list.first(wisp.path_segments(req))
    |> as_snag(
      "No file path found from url path segments (you should never get here)",
    ),
  )

  let path = data_path() <> name

  use exists <- result.try(
    simplifile.is_file(path)
    |> as_snag("File does not exist or june is lacking permission"),
  )
  use <- bool.guard(exists == False, snag.error("File does not exist"))

  Ok(path)
}

fn as_snag(res: Result(a, b), message: String) -> snag.Result(a) {
  case res {
    Ok(_) -> Nil
    Error(_) -> wisp.log_warning(message)
  }

  res
  |> result.replace_error(snag.new(message))
}
