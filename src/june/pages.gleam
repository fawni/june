import nakai
import nakai/attr
import nakai/html
import wisp

fn document(children: List(html.Node)) -> html.Node {
  html.Html([], [
    html.Head([
      html.title("June"),
      html.meta([attr.name("description"), attr.content("pomf clone too 🌈")]),
      html.link([
        attr.rel("icon"),
        attr.type_("image/svg+xml"),
        attr.href("/public/favicon.svg"),
      ]),
      html.meta([attr.name("theme-color"), attr.content("#d895ee")]),
      html.meta([
        attr.name("viewport"),
        attr.content("width=device-width, initial-scale=1.0"),
      ]),
      html.link([attr.href("/public/css/june.css"), attr.rel("stylesheet")]),
      html.link([
        attr.href("https://fonts.googleapis.com"),
        attr.rel("preconnect"),
      ]),
      html.link([
        attr.href("https://fonts.gstatic.com"),
        attr.rel("preconnect"),
        attr.crossorigin(""),
      ]),
      html.link([
        attr.href(
          "https://fonts.googleapis.com/css2?family=JetBrains+Mono&display=swap",
        ),
        attr.rel("stylesheet"),
      ]),
      html.link([
        attr.href("https://unpkg.com/@twinking/macaron@0.1.6/dist/macaron.css"),
        attr.rel("stylesheet"),
      ]),
      html.Element(
        "script",
        [
          attr.src("https://unpkg.com/@twinking/macaron@0.1.6/dist/macaron.js"),
          attr.type_("text/javascript"),
        ],
        [],
      ),
    ]),
    html.Body([attr.class("overflow-hidden")], [
      html.div([attr.class("hero bg-base-100 min-h-screen")], [
        html.div([attr.class("hero-content text-center")], [
          html.div([attr.class("max-w-md")], [
            html.h1_text(
              [attr.class("text-3xl font-bold text-primary")],
              "June",
            ),
            html.div(
              [
                attr.class(
                  "flex py-6 whitespace-pre justify-center align-center",
                ),
              ],
              [
                html.span_text([], "Made with "),
                html.span_text([attr.class("text-error")], "♡"),
                html.span_text([], " by "),
                html.a_text(
                  [
                    attr.class("font-bold text-secondary"),
                    attr.href("https://fawn.moe"),
                  ],
                  "fawn",
                ),
              ],
            ),
            html.Fragment(children),
          ]),
        ]),
      ]),
      html.footer(
        [
          attr.class(
            "footer footer-center bg-base-200 text-base-content p-4 sticky bottom-0",
          ),
        ],
        [
          html.span([attr.class("flex")], [
            html.Text("Copyright (c) 2024 "),
            html.b_text([], "fawn"),
            html.p_text([attr.class("text-error")], "♡"),
            html.a_text(
              [
                attr.href("https://github.com/fawni/june"),
                attr.class("text-secondary"),
              ],
              " Source code",
            ),
          ]),
        ],
      ),
    ]),
  ])
}

pub fn home() -> wisp.Response {
  document([
    html.form(
      [attr.enctype("multipart/form-data"), attr.id("form"), attr.class("mt-8")],
      [
        html.input([
          attr.type_("file"),
          attr.name("file"),
          attr.class(
            "file-input file-input-bordered file-input-info w-full max-w-xs",
          ),
        ]),
        html.input([
          attr.type_("password"),
          attr.name("token"),
          attr.placeholder("Token"),
          attr.class("input input-bordered input-info w-full max-w-xs my-6"),
        ]),
        html.label(
          [attr.class("label inline-flex cursor-pointer whitespace-pre mb-8")],
          [
            html.input([
              attr.name("stay"),
              attr.type_("checkbox"),
              attr.checked(),
              attr.class("checkbox checkbox-info"),
            ]),
            html.span_text([], " Stay on page"),
          ],
        ),
        html.div([], [
          html.button_text([attr.class("btn btn-success")], "Upload"),
        ]),
      ],
    ),
    html.Script(
      [],
      "
      const form = document.getElementById('form');

      const handleSubmit = async (event) => {
        event.preventDefault();
        const formData = new FormData(event.target);

        if (form.elements.file.files.length === 0) {
          macaron.error('error: No file provided');
          return;
        }
        
        macaron.info('Uploading...');
        let res = await fetch('/', {
          method: 'POST',
          body: formData,
        }).catch((e) => {
          macaron.error('Error uploading file', e);
        });

        const body = await res.text();
        if (res.status === 201) {
          console.log('uploaded ' + body);
          if (formData.get('stay')) {
            await navigator.clipboard.writeText(window.location.href + body);
            macaron.success('Copied to clipboard! Click to view', { action: () => window.location.href = '/' + body });
          } else {
            window.location.href = body;
          }
        } else {
          macaron.error('Failed to upload ' + formData.get('file')?.name + '\\n' + body);
        }
      };

      form.addEventListener('submit', handleSubmit);",
    ),
  ])
  |> nakai.to_string_builder()
  |> wisp.html_response(200)
}

pub fn not_found(message: String) -> wisp.Response {
  document([
    html.p_text([attr.class("text-error")], message),
    html.img([attr.src("/public/assets/menhera.png"), attr.class("mt-6")]),
  ])
  |> nakai.to_string_builder
  |> wisp.html_response(404)
}
