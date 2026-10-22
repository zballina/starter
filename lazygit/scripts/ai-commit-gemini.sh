#!/usr/bin/env bash
# Provider interface: prepare configuration, then set MSG from PROMPT.

prepare_ai_commit_provider() {
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
    return 1
  fi

  if ! command -v jq &>/dev/null || ! command -v curl &>/dev/null; then
    echo "❌ Error: 'jq' o 'curl' no está instalado en tu sistema."
    return 1
  fi

  return 0
}

generate_ai_commit_message() {
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
      echo "🤖 Generating commit message with ${CURRENT_MODEL} (${PROMPT_SIZE_HUMAN:-unknown size}, attempt ${attempt}/${GEMINI_MAX_RETRIES})..."

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
    return 1
  fi

  return 0
}
