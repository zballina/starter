#!/usr/bin/env bash
# Read only the settings used by this integration, using the user's shell.
# Inherited values win, including per-command provider/model overrides.
load_ai_commit_environment() {
  local name value shell_path=""
  local names=(AI_COMMIT_PROVIDER AI_COMMIT_MAX_DIFF_LINES CODEX_COMMIT_MODEL CODEX_COMMIT_BIN GEMINI_API_KEY GEMINI_MODEL GEMINI_FALLBACK_MODELS GEMINI_TEMPERATURE GEMINI_MAX_TOKENS GEMINI_MAX_DIFF_LINES GEMINI_MAX_RETRIES PATH)
  local settings_file
  settings_file=$(mktemp "${TMPDIR:-/tmp}/ai_commit_env.XXXXXX") || return 1
  if command -v zsh >/dev/null 2>&1; then
    zsh -ic 'for name in "$@"; do printf "%s\0%s\0" "$name" "${(P)name}" >&3; done' -- "${names[@]}" 3>"$settings_file" >/dev/null 2>&1 || true
  elif command -v bash >/dev/null 2>&1; then
    bash -ic 'for name in "$@"; do printf "%s\0%s\0" "$name" "${!name}" >&3; done' -- "${names[@]}" 3>"$settings_file" >/dev/null 2>&1 || true
  fi
  while IFS= read -r -d '' name && IFS= read -r -d '' value; do
    if [ "$name" = PATH ]; then
      shell_path="$value"
    elif [ -z "${!name}" ] && [ -n "$value" ]; then
      printf -v "$name" '%s' "$value"
      export "$name"
    fi
  done < "$settings_file"
  rm -f "$settings_file"
  export PATH="${PATH}:/opt/homebrew/bin:/usr/local/bin:/opt/local/bin:$HOME/.local/bin"
  # Append shell PATH: existing commands and test doubles retain precedence.
  [ -z "$shell_path" ] || export PATH="$PATH:$shell_path"
  AI_COMMIT_PROVIDER="${AI_COMMIT_PROVIDER:-gemini}"
}
