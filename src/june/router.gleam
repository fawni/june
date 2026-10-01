import dot_env/env
import filepath
import gleam/bit_array
import gleam/bool
import gleam/bytes_tree
import gleam/http
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import june/blake2b
import june/pages
import june/web
import simplifile
import snag
import wisp

const max_fetch_bytes = 26_214_400

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
    ["fetch"] -> handle_fetch(req)
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
    False -> wisp.html_response("invalid token", 403)
  }
}

fn handle_fetch(req: wisp.Request) -> wisp.Response {
  use <- wisp.require_method(req, http.Post)
  use formdata <- wisp.require_form(req)
  let token = wisp.get_secret_key_base(req)

  case validate_formdata(token, formdata) {
    #(_, Some(True)) -> {
      let fetched = {
        use url <- result.try(
          list.key_find(formdata.values, "url")
          |> as_snag("No URL provided"),
        )
        wisp.log_info("Fetching remote image " <> url)
        fetch_image(url)
      }

      case fetched {
        Ok(#(content_type, body)) ->
          wisp.response(200)
          |> wisp.set_header("content-type", content_type)
          |> wisp.set_body(wisp.Bytes(bytes_tree.from_bit_array(body)))
        Error(err) ->
          err
          |> snag.line_print
          |> wisp.html_response(400)
      }
    }
    #(invalid, Some(False)) -> {
      wisp.log_warning(
        "User attempted to fetch with an invalid token: \"" <> invalid <> "\"",
      )

      snag.new("Invalid token")
      |> snag.line_print
      |> wisp.html_response(403)
    }
    #(_, None) -> {
      wisp.log_warning("User attempted to fetch without a token")

      snag.new("Missing token")
      |> snag.line_print
      |> wisp.html_response(403)
    }
  }
}

fn fetch_image(url: String) -> snag.Result(#(String, BitArray)) {
  use target <- result.try(
    request.to(url)
    |> as_snag("Invalid URL"),
  )

  let target =
    target
    |> request.set_header(
      "user-agent",
      "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
    )
    |> request.set_body(<<>>)

  use resp <- result.try(
    httpc.send_bits(target)
    |> as_snag("Could not reach that URL"),
  )

  use <- bool.guard(
    resp.status != 200,
    snag.error("Remote server returned status " <> int.to_string(resp.status)),
  )

  let content_type =
    response.get_header(resp, "content-type")
    |> result.unwrap("")

  use <- bool.guard(
    string.starts_with(content_type, "image/") == False,
    snag.error("That URL is not an image"),
  )
  use <- bool.guard(
    bit_array.byte_size(resp.body) > max_fetch_bytes,
    snag.error("That image is too large"),
  )

  Ok(#(content_type, resp.body))
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
              |> wisp.html_response(200)
            }
            Error(err) -> {
              err
              |> snag.line_print
              |> wisp.html_response(400)
            }
          }
        }
        _ -> {
          case upload_file(formdata) {
            Ok(name) -> {
              wisp.created()
              |> wisp.html_body(name)
            }
            Error(err) -> {
              err
              |> snag.line_print
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
      |> wisp.html_response(400)
    }
    #(_, None) -> {
      wisp.log_warning("User attempted to upload without a token")

      snag.new("Missing token")
      |> snag.line_print
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
    Ok(path) -> wisp.ok() |> wisp.set_body(wisp.File(path, 0, option.None))
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
