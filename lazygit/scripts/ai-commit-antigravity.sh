#!/usr/bin/env bash
# Provider interface: prepare configuration, then set MSG from PROMPT.

prepare_ai_commit_provider() {
  ANTIGRAVITY_COMMIT_BIN="${ANTIGRAVITY_COMMIT_BIN:-agy}"
  ANTIGRAVITY_COMMIT_TIMEOUT="${ANTIGRAVITY_COMMIT_TIMEOUT:-60s}"
  if ! command -v "$ANTIGRAVITY_COMMIT_BIN" >/dev/null 2>&1; then
    echo "Error: Antigravity CLI no está disponible. Instala agy o configura ANTIGRAVITY_COMMIT_BIN."
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: Antigravity requiere jq para procesar la respuesta."
    return 1
  fi
  # A zero timeout means unlimited execution in agy; require a finite duration.
  if ! printf '%s\n' "$ANTIGRAVITY_COMMIT_TIMEOUT" | grep -Eq '^[1-9][0-9]*(ms|s|m|h)$'; then
    echo "Error: ANTIGRAVITY_COMMIT_TIMEOUT debe ser una duración positiva, por ejemplo 60s."
    return 1
  fi
  return 0
}

generate_ai_commit_message() {
  local request response
  local -a arguments
  AI_COMMIT_OUTPUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/ai_commit_antigravity.XXXXXX") || return 1
  arguments=(--input-format stream-json --output-format stream-json --disable-slash-commands --sandbox --print-timeout "$ANTIGRAVITY_COMMIT_TIMEOUT")
  [ -z "$ANTIGRAVITY_COMMIT_MODEL" ] || arguments+=(--model "$ANTIGRAVITY_COMMIT_MODEL")
  request=$(jq -nc --arg prompt "$PROMPT" '{event: "user", message: {content: $prompt}}') || return 1
  echo "Generating commit message with Antigravity..."
  # Keep the repository outside the active workspace. Use cached account auth;
  # never extract tokens or grant tools additional permissions.
  if ! (
    cd "$AI_COMMIT_OUTPUT_DIR" || exit 1
    # This provider must use account authentication, even when Gemini's key is
    # configured in the same shell. A configured API-key provider fails closed.
    unset GEMINI_API_KEY GOOGLE_API_KEY
    printf '%s\n' "$request" | "$ANTIGRAVITY_COMMIT_BIN" "${arguments[@]}"
  ) > "$AI_COMMIT_OUTPUT_DIR/response" 2> "$AI_COMMIT_OUTPUT_DIR/stderr"; then
    echo "Error: Antigravity no pudo generar el mensaje. Verifica tu sesión ejecutando agy. No se cambiará de proveedor automáticamente."
    cat "$AI_COMMIT_OUTPUT_DIR/stderr" >&2
    return 1
  fi
  response=$(jq -sce '[.[] | select(.event == "result") | .result] | if length == 1 then .[0] else error("Expected one result") end' "$AI_COMMIT_OUTPUT_DIR/response" 2>/dev/null) || {
    echo "Error: Antigravity devolvió una respuesta inválida."
    return 1
  }
  MSG=$(printf '%s\n' "$response" | jq -er 'select(.status == "SUCCESS") | .response | select(type == "string" and length > 0)') || {
    echo "Error: Antigravity no completó la generación del mensaje."
    printf '%s\n' "$response" | jq -r '.error // .status' >&2
    cat "$AI_COMMIT_OUTPUT_DIR/stderr" >&2
    return 1
  }
  return 0
}
