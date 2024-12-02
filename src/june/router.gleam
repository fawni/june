import filepath
import gleam/bool
import gleam/http
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
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
    ["verify"] -> handle_verify(req)
    _ -> handle_retrieve_file(req)
  }
}

fn handle_verify(req: wisp.Request) -> wisp.Response {
  use body <- wisp.require_string_body(req)

  let verify =
    req
    |> wisp.get_secret_key_base
    |> validate_token(body)

  case verify {
    True -> wisp.ok() |> wisp.string_body("valid token")
    False ->
      wisp.html_response("invalid token" |> string_builder.from_string, 403)
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

  case validate_formdata(token, formdata) {
    #(_, Some(True)) -> {
      let to_delete = list.key_find(formdata.values, "delete")
      case to_delete {
        Ok(file_name) -> {
          case delete_file(file_name) {
            Ok(msg) -> {
              msg
              |> string_builder.from_string
              |> wisp.html_response(200)
            }
            Error(err) -> {
              err
              |> snag.line_print
              |> string_builder.from_string
              |> wisp.html_response(400)
            }
          }
        }
        _ -> {
          case upload_file(formdata) {
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
      }
    }
    #(invalid, Some(False)) -> {
      wisp.log_warning(
        "User attempted to upload with an invalid token: \"" <> invalid <> "\"",
      )

      snag.new("Invalid token: \"" <> invalid <> "\"")
      |> snag.line_print
      |> string_builder.from_string
      |> wisp.html_response(400)
    }
    #(_, None) -> {
      wisp.log_warning("User attempted to upload without a token")

      snag.new("Missing token")
      |> snag.line_print
      |> string_builder.from_string
      |> wisp.html_response(400)
    }
  }
}

fn validate_token(june_token: String, token: String) -> Bool {
  june_token == token
}

fn validate_formdata(
  june_token: String,
  formdata: wisp.FormData,
) -> #(String, Option(Bool)) {
  case list.key_find(formdata.values, "token") {
    Ok(token) if token == june_token -> #(token, Some(True))
    Ok(invalid) if invalid != "" -> #(invalid, Some(False))
    _ -> #("", None)
  }
}

fn upload_file(formdata: wisp.FormData) -> snag.Result(String) {
  use file <- result.try(
    list.key_find(formdata.files, "file")
    |> as_snag("No file provided"),
  )

  wisp.log_info("Uploading " <> file.file_name)

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

fn delete_file(file_name: String) -> snag.Result(String) {
  case simplifile.delete(data_path() <> file_name) {
    Ok(_) -> {
      wisp.log_warning("Deleted file " <> file_name)

      Ok("File deleted successfully")
    }
    Error(_) -> {
      wisp.log_warning(
        "User attempted to delete non-existent file " <> file_name,
      )
      snag.error("Could not delete file as it does not exist")
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
