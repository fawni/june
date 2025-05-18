import gleam/string_tree
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
      html.Element(
        "script",
        [
          attr.src("https://unpkg.com/axios/dist/axios.min.js"),
          attr.type_("text/javascript"),
        ],
        [],
      ),
    ]),
    html.Body([], [
      html.div(
        [attr.class("hero bg-base-100 min-h-[calc(100vh-20px-2*16px)]")],
        [
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
        ],
      ),
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
        html.div([], [
          html.button_text([attr.class("btn btn-success")], "Upload"),
        ]),
        html.div(
          [
            attr.class("progress-container p-6 hidden"),
            attr.id("upload-progress-container"),
          ],
          [
            html.div_text([attr.id("upload-name"), attr.class("break-all")], ""),
            html.div_text([attr.id("upload-size"), attr.class("font-bold")], ""),
            html.progress(
              [
                attr.class("progress progress-info w-full"),
                attr.id("upload-progress"),
                attr.value("0"),
                attr.Attr("max", "100"),
              ],
              [],
            ),
          ],
        ),
        html.a_text([attr.id("upload-result"), attr.class("hidden font-bold text-primary pt-4")], "Result")
      ],
    ),
    html.Script(
      [],
      "
      const form = document.getElementById('form');
      const fileInput = document.querySelector('input[type=\\'file\\']');
      const progressContainer = document.getElementById('upload-progress-container');
      const progressName = document.getElementById('upload-name');
      const progressSize = document.getElementById('upload-size');
      const progressBar = document.getElementById('upload-progress');
      const uploadResult = document.getElementById('upload-result');

      function formatBytes(bytes, decimals = 1) {
        if (bytes === 0) return '0 Bytes';
        const k = 1000;
        const dm = decimals < 0 ? 0 : decimals;
        const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(dm)) + ' ' + sizes[i];
      }

      const handleSubmit = async (event) => {
        event.preventDefault();
        const formData = new FormData(form);

        if (form.elements.file.files.length === 0) {
          macaron.error('error: No file provided');
          return;
        }

        const file = form.elements.file.files[0];
        const fileName = file.name;
        const fileSize = formatBytes(file.size);

        let verify = await axios.post('/verify',
          formData.get('token'),
        ).catch((e) => {
          macaron.error('Error verifying token', e);
        });

        if (verify.status !== 200) {
          macaron.error('error: Invalid token');
          return;
        }

        progressName.innerText = fileName;
        progressSize.innerText = fileSize;
        progressContainer.classList.remove('hidden');
        progressBar.value = 0;
        uploadResult.classList.add('hidden');

        axios.post('/', formData, {
        onUploadProgress: (progressEvent) => {
          if (progressEvent.lengthComputable) {
            const percentComplete = (progressEvent.loaded / progressEvent.total) * 100;
            progressBar.value = percentComplete;
          }
        }
        }).then(response => {
          console.log('uploaded: ' + response.data);
          macaron.success('Successfully uploaded!', { action: () => window.location.href = '/' + response.data, timeout: 10000 });
          uploadResult.href = '/' + response.data;
          uploadResult.classList.remove('hidden');
        }).catch(error => {
            macaron.error('Failed to upload: ' + error.message);
        });
      };

      form.addEventListener('submit', handleSubmit);

      function dataURItoFile(dataURI) {
        var byteString;
        if (dataURI.split(',')[0].indexOf('base64') >= 0)
          byteString = atob(dataURI.split(',')[1]);
        else
          byteString = unescape(dataURI.split(',')[1]);

        var mimeString = dataURI.split(',')[0].split(':')[1].split(';')[0];
        var ext = mimeString.split('/')[1];

        var ia = new Uint8Array(byteString.length);
        for (var i = 0; i < byteString.length; i++) {
          ia[i] = byteString.charCodeAt(i);
        }

        var blob = new Blob([ia], {type:mimeString});

        return new File([blob], `clipboard.${ext}`, {type: mimeString});
      }

      document.onpaste = function(event) {
        var items = (event.clipboardData || event.originalEvent.clipboardData).items;
        for (index in items) {
          var item = items[index];
          if (item.kind === 'file') {
            var blob = item.getAsFile();
            var reader = new FileReader();
            reader.onload = function(event) {
              var file = dataURItoFile(event.target.result);
              const dataTransfer = new DataTransfer();
              dataTransfer.items.add(file);
              fileInput.files = dataTransfer.files;
            }; 
            reader.readAsDataURL(blob);
            macaron.info('Pasted from your clipboard');
          };
        };
      };
    ",
    ),
  ])
  |> nakai.to_string
  |> string_tree.from_string
  |> wisp.html_response(200)
}

pub fn not_found(message: String) -> wisp.Response {
  document([
    html.p_text([attr.class("text-error")], message),
    html.img([attr.src("/public/assets/menhera.png"), attr.class("mt-6")]),
  ])
  |> nakai.to_string
  |> string_tree.from_string
  |> wisp.html_response(404)
}
