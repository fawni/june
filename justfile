_default:
    @just --list

@init:
    gleam deps download
    gleam run -m tailwind/install

@tailwind:
    gleam run -m tailwind/run

@run: (tailwind)
    gleam run
