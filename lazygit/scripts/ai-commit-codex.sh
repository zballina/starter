#!/usr/bin/env bash
# Provider interface: prepare configuration, then set MSG from PROMPT.

prepare_ai_commit_provider() {
  CODEX_COMMIT_BIN="${CODEX_COMMIT_BIN:-codex}"
  if ! command -v "$CODEX_COMMIT_BIN" >/dev/null 2>&1; then
    echo "Error: Codex CLI no está disponible. Configura CODEX_COMMIT_BIN o instala Codex."
    return 1
  fi
  if ! "$CODEX_COMMIT_BIN" login status >/dev/null 2>&1; then
    echo "Error: Inicia sesión primero con codex login."
    return 1
  fi
  return 0
}

generate_ai_commit_message() {
  AI_COMMIT_OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ai_commit_codex.XXXXXX") || return 1
  CODEX_ARGS=(exec --sandbox read-only --ephemeral --color never --skip-git-repo-check --cd "$AI_COMMIT_OUTPUT_DIR" --output-last-message "$AI_COMMIT_OUTPUT_DIR/message")
  [ -z "$CODEX_COMMIT_MODEL" ] || CODEX_ARGS+=(--model "$CODEX_COMMIT_MODEL")
  echo "Generating commit message with Codex (${PROMPT_SIZE_HUMAN:-unknown size})..."
  if ! printf '%s\n' "$PROMPT" | "$CODEX_COMMIT_BIN" "${CODEX_ARGS[@]}" - > /dev/null 2> "$AI_COMMIT_OUTPUT_DIR/stderr"; then
    echo "Error: Codex no pudo generar el mensaje. No se cambiará de proveedor automáticamente."
    # Show diagnostics only on failure, keeping successful generation quiet.
    cat "$AI_COMMIT_OUTPUT_DIR/stderr" >&2
    return 1
  fi
  if [ ! -s "$AI_COMMIT_OUTPUT_DIR/message" ]; then
    echo "Error: Codex devolvió una respuesta vacía."
    return 1
  fi
  MSG=$(cat "$AI_COMMIT_OUTPUT_DIR/message")
  return 0
}
