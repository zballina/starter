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

Supported values are `gemini`, `codex`, and `antigravity`.
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

For Antigravity using your signed-in Google account, select:

```sh
export AI_COMMIT_PROVIDER="antigravity"
```

Antigravity requires `agy` on PATH, `jq`, and a cached account session. Open `agy`
interactively once to sign in with the account associated with your subscription.
The integration delegates authentication to the CLI and never reads account
tokens. Keep agy on its default account provider: if you have explicitly set
`modelProvider` to `gemini` in agy's settings, switch it back before using this
flow. The integration removes `GEMINI_API_KEY` and `GOOGLE_API_KEY` only from
agy's subprocess so it cannot silently use those keys. Both variables remain
available in your shell and in the separate `gemini` flow.

Optional Antigravity settings:

```sh
export ANTIGRAVITY_COMMIT_BIN="/absolute/path/to/agy"
export ANTIGRAVITY_COMMIT_MODEL="your-available-model"
export ANTIGRAVITY_COMMIT_TIMEOUT="60s"
```

Omit the model setting to use agy's default; use `agy models` to list available
models. The timeout defaults to 60 seconds and must be a positive integer followed
by `ms`, `s`, `m`, or `h`. Antigravity receives the prompt and diff through stdin
as a single JSON event, runs in a temporary workspace with terminal sandboxing,
and returns a validated result. Its sandbox follows agy's tool permission
settings; it does not provide Codex's `read-only` sandbox guarantee. No additional
tool permissions are granted. Authentication failures, timeouts, and invalid
responses abort without switching providers. Subscription access remains subject
to the account's available models and usage limits.

Provider configuration and generation live in separate files:
`lazygit/scripts/ai-commit-gemini.sh`, `ai-commit-codex.sh`, and
`ai-commit-antigravity.sh`. The shared `ai-commit.sh` handles the staged diff,
message validation, editor review, and commit confirmation.

References: [Antigravity headless mode](https://antigravity.google/docs/cli/headless/)
and [authentication](https://antigravity.google/docs/install?tab=cli).

# Neo-tree con varios repositorios

Neo-tree es el explorador de archivos y se abre a la izquierda. `Ctrl-n` lo
muestra u oculta y `Espacio e` lo abre o enfoca. NvimTree está deshabilitado;
el selector de LazyGit sigue disponible con `Espacio g g`. Reinicia NvChad
después de cambiar la configuración para cargar los atajos.

Desde el directorio que contiene los repositorios, abre NvChad y pulsa
`Ctrl-n`. También puedes indicar una raíz desde Neovim:

```vim
:Neotree filesystem left dir=/ruta/al/directorio/raiz
```

Las carpetas visibles que contienen un repositorio Git se consultan de forma
asíncrona sin desplegarlas. Una marca `●` en la raíz del repositorio indica
cambios pendientes, incluidos cambios en stage, sin stage, archivos nuevos y
conflictos. Los archivos ignorados no activan la marca y los repositorios
limpios no muestran ninguna. No se recorren recursivamente las carpetas cerradas:
si un repositorio está dentro de otra carpeta, despliega esa carpeta contenedora.

Despliega los repositorios con `Enter` o `Espacio` para ver el detalle.
Los archivos muestran `S` para cambios en
stage, `U` para cambios sin stage, `?` para archivos nuevos y `!` para
conflictos, junto con indicadores del tipo de cambio. Si un archivo tiene
cambios en stage y sin stage, aparecen dos indicadores del tipo de cambio.
Pulsa `R` para actualizar el árbol y volver a consultar el estado Git de los
repositorios ya detectados bajo esa raíz. Este atajo incluye un ajuste local
porque el refresco original puede conservar estados de repositorios anidados.
Pulsa `?` para consultar los atajos y `q` para cerrar.

El explorador utiliza el árbol de archivos: no agrupa todos los archivos
modificados en una lista global. La raíz de Neo-tree no cambia al abrir un
archivo y navegar por el árbol no cambia el directorio de trabajo de Neovim.
