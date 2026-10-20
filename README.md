**This repo is supposed to be used as config by NvChad users!**

- The main nvchad repo (NvChad/NvChad) is used as a plugin by this repo.
- So you just import its modules , like `require "nvchad.options" , require "nvchad.mappings"`
- So you can delete the .git from this repo ( when you clone it locally ) or fork it :)

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!

# AI commit messages

In LazyGit, stage the desired files and press `Ctrl-g`. The message is generated
in English using Conventional Commits, then opened in Neovim for review.
Press Enter in Normal mode to save and confirm, or `:cq` to cancel.

Choose the provider in `~/.zshrc`:

```sh
export AI_COMMIT_PROVIDER="codex"
```

Use `gemini` to return to Gemini. An unset selector defaults to Gemini; existing
`GEMINI_API_KEY`, model, fallback and retry settings are preserved. The legacy
`gemini-commit.sh` entry point always selects Gemini.

Codex requires Codex CLI on PATH and an authenticated session (`codex login`).
It reuses that session, so ChatGPT authentication needs no additional API key.
Optional settings:

```sh
export CODEX_COMMIT_BIN="/absolute/path/to/codex"
export CODEX_COMMIT_MODEL="your-available-model"
export AI_COMMIT_MAX_DIFF_LINES="250"
```

Omit `CODEX_COMMIT_MODEL` to use Codex's configured default. The common diff limit
falls back to `GEMINI_MAX_DIFF_LINES`, then 250. Lockfiles and `.DS_Store` are
excluded, as before. Only staged changes are sent; a truncated diff can omit
relevant changes in large commits.

Inherited settings take precedence. For launches from Finder, the integration
loads missing settings and appends PATH from an interactive Zsh subprocess
(including NVM initialization), without sourcing Zsh files in Bash. Shell startup
files should support interactive shells without a TTY. After editing `.zshrc`,
open a new terminal and restart Neovim to refresh inherited settings.
For a temporary override, launch with `AI_COMMIT_PROVIDER=codex nvim`.

Codex runs in a read-only sandbox in a temporary directory and receives the diff
via stdin. It only generates the message; the shell script performs the commit
after editor confirmation. Errors and invalid output abort the flow without
switching providers. The installer checks dependencies for the selected provider.

# Prueba de Neo-tree con varios repositorios

Neo-tree se abre a la derecha con `Espacio g e` y convive con NvimTree
(`Ctrl-n`) y el selector de LazyGit (`Espacio g g`). Reinicia NvChad después
de instalarlo para cargar el nuevo atajo.

Desde el directorio que contiene los repositorios, abre NvChad y pulsa
`Espacio g e`. También puedes indicar una raíz desde Neovim:

```vim
:Neotree filesystem right dir=/ruta/al/directorio/raiz
```

Despliega las carpetas de los repositorios con `Enter` o `Espacio` para que
Neo-tree detecte su estado Git. Los archivos muestran `S` para cambios en
stage, `U` para cambios sin stage, `?` para archivos nuevos y `!` para
conflictos, junto con indicadores del tipo de cambio. Si un archivo tiene
cambios en stage y sin stage, aparecen dos indicadores del tipo de cambio.
Pulsa `R` para actualizar el árbol y volver a consultar el estado Git de los
repositorios ya detectados bajo esa raíz. Este atajo incluye un ajuste local
porque el refresco original puede conservar estados de repositorios anidados.
Pulsa `?` para consultar los atajos y `q` para cerrar.

Esta prueba utiliza el árbol de archivos: no agrupa todos los archivos
modificados en una lista global. La raíz de Neo-tree no cambia al abrir un
archivo y navegar por el árbol no cambia el directorio de trabajo de Neovim.
