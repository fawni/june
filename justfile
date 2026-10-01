_default:
    @just --list

@init:
    gleam deps download

@tailwind:
    bunx tailwindcss@3.4.19 --config=tailwind.config.js --input=./src/css/june.css --output=./priv/static/css/june.css --minify

@run: (tailwind)
    gleam run

push:
    git push
    git push gh
