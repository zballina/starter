#!/usr/bin/env bash

# ==============================================================================
# 1. Cargar entorno del usuario (Zsh / Bash) y PATH
# ==============================================================================
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" >/dev/null 2>&1
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" >/dev/null 2>&1

export PATH="/usr/local/bin:/opt/homebrew/bin:$HOME/.local/bin:$PATH"

# Editor para la revisión
export EDITOR="${EDITOR:-nvim}"

# ==============================================================================
# 2. Configuración de Gemini API y Fallbacks
# ==============================================================================
GEMINI_MODEL="${GEMINI_MODEL:-gemini-2.5-flash}"
DEFAULT_FALLBACKS=("gemini-2.5-flash-lite" "gemini-flash-latest")

if [ -n "$GEMINI_FALLBACK_MODELS" ]; then
  IFS=', ' read -r -a USER_FALLBACKS <<< "$GEMINI_FALLBACK_MODELS"
else
  USER_FALLBACKS=("${DEFAULT_FALLBACKS[@]}")
fi

MODELS=("$GEMINI_MODEL")
for m in "${USER_FALLBACKS[@]}"; do
  if [ "$m" != "$GEMINI_MODEL" ]; then
    MODELS+=("$m")
  fi
done

GEMINI_TEMPERATURE="${GEMINI_TEMPERATURE:-0.1}"
GEMINI_MAX_TOKENS="${GEMINI_MAX_TOKENS:-80}"
GEMINI_MAX_DIFF_LINES="${GEMINI_MAX_DIFF_LINES:-250}"
GEMINI_MAX_RETRIES="${GEMINI_MAX_RETRIES:-2}"

if [ -z "$GEMINI_API_KEY" ]; then
  echo "❌ Error: La variable GEMINI_API_KEY no está definida en tu entorno."
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "❌ Error: 'jq' no está instalado en tu sistema."
  exit 1
fi

# ==============================================================================
# 3. Validar archivos en Stage y obtener git diff
# ==============================================================================
# Forzar que al menos un archivo esté en el stage
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$STAGED_FILES" ]; then
  echo "⚠️ Advertencia: No hay archivos seleccionados en el stage."
  echo "   En lazygit, presiona 'space' sobre los archivos que deseas commitear (o 'a' para todos)."
  exit 1
fi

DIFF=$(git diff --cached -- ':!*.DS_Store' ':!*.lock' 2>/dev/null || true)

if [ -z "$DIFF" ]; then
  echo "⚠️ Advertencia: Hay archivos staged, pero no se detectaron cambios de texto analizables (solo binarios o archivos ignorados)."
  exit 1
fi

DIFF_TRUNCATED=$(echo "$DIFF" | head -n "$GEMINI_MAX_DIFF_LINES")

# ==============================================================================
# 4. Prompt y llamada a la API con Fallback y Retry (Salida en Inglés)
# ==============================================================================
PROMPT="Act as a senior software engineer. Generate a concise commit message in ENGLISH following the Conventional Commits specification (e.g., feat, fix, refactor, chore, docs, test) for the following git diff. Return ONLY the one-line commit message, with no markdown code blocks, backticks, or extra explanation:

$DIFF_TRUNCATED"

PAYLOAD=$(jq -nc \
  --arg prompt "$PROMPT" \
  --argjson temp "$GEMINI_TEMPERATURE" \
  --argjson max_tokens "$GEMINI_MAX_TOKENS" \
  '{
    contents: [{ parts: [{ text: $prompt }] }],
    generationConfig: {
      temperature: $temp,
      maxOutputTokens: $max_tokens,
      thinkingConfig: { thinkingBudget: 0 }
    }
  }')

MSG=""
LAST_ERROR=""

for ((attempt=1; attempt<=GEMINI_MAX_RETRIES; attempt++)); do
  for CURRENT_MODEL in "${MODELS[@]}"; do
    echo "🤖 Generating commit message with ${CURRENT_MODEL} (attempt ${attempt}/${GEMINI_MAX_RETRIES})..."

    API_URL="https://generativelanguage.googleapis.com/v1beta/models/${CURRENT_MODEL}:generateContent?key=${GEMINI_API_KEY}"

    RESPONSE=$(curl -s --http2 --max-time 12 -X POST "$API_URL" \
      -H "Content-Type: application/json" \
      -d "$PAYLOAD")

    MSG=$(printf "%s\n" "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null | tr -d '`' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    if [ -n "$MSG" ]; then
      break 2
    fi

    HTTP_CODE=$(printf "%s\n" "$RESPONSE" | jq -r '.error.code // empty' 2>/dev/null)
    ERROR_MSG=$(printf "%s\n" "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)
    LAST_ERROR="${ERROR_MSG:-Empty response or timeout}"

    if [ -n "$ERROR_MSG" ]; then
      echo "⚠️ ${CURRENT_MODEL} failed (HTTP ${HTTP_CODE:-error}): ${ERROR_MSG}"
    else
      echo "⚠️ ${CURRENT_MODEL} returned an empty response or timed out."
    fi
  done

  if [ -z "$MSG" ] && [ "$attempt" -lt "$GEMINI_MAX_RETRIES" ]; then
    echo "⏳ All candidate models busy or rate-limited. Retrying in 2 seconds..."
    sleep 2
  fi
done

if [ -z "$MSG" ]; then
  echo "❌ Error: All Gemini models failed to generate a commit message."
  [ -n "$LAST_ERROR" ] && echo "   Last error: $LAST_ERROR"
  exit 1
fi

# ==============================================================================
# 5. Archivo temporal y revisión en Editor
# ==============================================================================
COMMIT_MSG_FILE=$(mktemp /tmp/gemini_commit_msg.XXXXXX)

cat <<EOF > "$COMMIT_MSG_FILE"
$MSG

# ----------------------------------------------------------------------
# Líneas que comiencen con '#' serán ignoradas automáticamente por Git.
# - Para CONFIRMAR: presiona ENTER (o guarda y sal con :wq).
# - Para ABORTAR: sal con error (:cq) o borra el texto y guarda (:wq).
# ----------------------------------------------------------------------
EOF

# Abrir el editor conectando explícitamente el TTY
"$EDITOR" "$COMMIT_MSG_FILE" < /dev/tty > /dev/tty
EDITOR_EXIT_CODE=$?

# Si saliste del editor con código de error (:cq en nvim/vim)
if [ $EDITOR_EXIT_CODE -ne 0 ]; then
  echo "🚫 Commit abortado (editor cerrado sin confirmar)."
  rm -f "$COMMIT_MSG_FILE"
  exit 0
fi

# Verificar si el archivo tiene texto real fuera de los comentarios
CLEANED_MSG=$(grep -v '^[[:space:]]*#' "$COMMIT_MSG_FILE" | tr -d '[:space:]')

if [ -z "$CLEANED_MSG" ]; then
  echo "🚫 Commit abortado (mensaje vacío)."
  rm -f "$COMMIT_MSG_FILE"
  exit 0
fi

# ==============================================================================
# 6. Ejecutar el Commit (descartando líneas comentadas con '#')
# ==============================================================================
git commit --cleanup=strip -F "$COMMIT_MSG_FILE"
rm -f "$COMMIT_MSG_FILE"
