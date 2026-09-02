#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_LAZYGIT="$SCRIPT_DIR/lazygit"
TARGET_LAZYGIT="$HOME/.config/lazygit"
ZSHRC="$HOME/.zshrc"

echo "========================================================"
echo "🚀 Configurando LazyGit con integración de Gemini AI..."
echo "========================================================"

# ------------------------------------------------------------------------------
# 1. Validar directorio fuente en el repositorio
# ------------------------------------------------------------------------------
if [ ! -d "$REPO_LAZYGIT" ]; then
  echo "❌ Error: No se encontró la carpeta lazygit en el repositorio ($REPO_LAZYGIT)."
  exit 1
fi

# ------------------------------------------------------------------------------
# 2. Gestionar enlace simbólico (~/.config/lazygit)
# ------------------------------------------------------------------------------
mkdir -p "$HOME/.config"

if [ -L "$TARGET_LAZYGIT" ]; then
  CURRENT_LINK="$(readlink "$TARGET_LAZYGIT" || true)"
  if [ "$CURRENT_LINK" = "$REPO_LAZYGIT" ]; then
    echo "✅ El enlace simbólico ~/.config/lazygit ya existe y apunta correctamente al repositorio."
  else
    echo "⚠️ ~/.config/lazygit apunta a '$CURRENT_LINK'. Actualizando a '$REPO_LAZYGIT'..."
    rm -f "$TARGET_LAZYGIT"
    ln -s "$REPO_LAZYGIT" "$TARGET_LAZYGIT"
    echo "✅ Enlace simbólico actualizado."
  fi
elif [ -d "$TARGET_LAZYGIT" ]; then
  BACKUP_DIR="${TARGET_LAZYGIT}.backup.$(date +%Y%m%d_%H%M%S)"
  echo "⚠️ Se detectó una carpeta existente en ~/.config/lazygit que no es un enlace simbólico."
  echo "📦 Creando respaldo en: $BACKUP_DIR"
  mv "$TARGET_LAZYGIT" "$BACKUP_DIR"
  ln -s "$REPO_LAZYGIT" "$TARGET_LAZYGIT"
  echo "✅ Enlace simbólico creado exitosamente."
else
  ln -s "$REPO_LAZYGIT" "$TARGET_LAZYGIT"
  echo "✅ Enlace simbólico creado: ~/.config/lazygit -> $REPO_LAZYGIT"
fi

# ------------------------------------------------------------------------------
# 3. Ajustar config.yml si existe (asegurar portabilidad entre máquinas)
# ------------------------------------------------------------------------------
CONFIG_FILE="$REPO_LAZYGIT/config.yml"
if [ -f "$CONFIG_FILE" ]; then
  echo "==> Verificando portabilidad en config.yml..."
  if grep -q "command:.*gemini-commit.sh" "$CONFIG_FILE"; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      sed -i '' -E 's|command:.*gemini-commit\.sh.*|command: "bash \\"\$HOME/.config/lazygit/scripts/gemini-commit.sh\\""|g' "$CONFIG_FILE"
    else
      sed -i -E 's|command:.*gemini-commit\.sh.*|command: "bash \\"\$HOME/.config/lazygit/scripts/gemini-commit.sh\\""|g' "$CONFIG_FILE"
    fi
    echo "✅ config.yml configurado con ruta portable (\$HOME)."
  fi
else
  echo "ℹ️ config.yml no encontrado en el repositorio. Omitiendo modificación."
fi

# ------------------------------------------------------------------------------
# 4. Validar GEMINI_API_KEY en ~/.zshrc
# ------------------------------------------------------------------------------
[ -f "$ZSHRC" ] || touch "$ZSHRC"

if grep -q "GEMINI_API_KEY" "$ZSHRC" 2>/dev/null; then
  echo "✅ GEMINI_API_KEY ya existe en tu ~/.zshrc. No se realizaron cambios."
else
  echo "==> GEMINI_API_KEY no detectada en ~/.zshrc."
  if [ -n "$GEMINI_API_KEY" ]; then
    echo "==> Guardando la clave de la sesión actual en ~/.zshrc..."
    echo "" >> "$ZSHRC"
    echo "# Google Gemini API Key para LazyGit" >> "$ZSHRC"
    echo "export GEMINI_API_KEY=\"$GEMINI_API_KEY\"" >> "$ZSHRC"
    echo "✅ Clave añadida a ~/.zshrc."
  else
    echo "ℹ️ Introduce tu GEMINI_API_KEY (presiona Enter para omitir): "
    read -r KEY_INPUT
    if [ -n "$KEY_INPUT" ]; then
      echo "" >> "$ZSHRC"
      echo "# Google Gemini API Key para LazyGit" >> "$ZSHRC"
      echo "export GEMINI_API_KEY=\"$KEY_INPUT\"" >> "$ZSHRC"
      echo "✅ Clave añadida a ~/.zshrc."
    else
      echo "⚠️ No se ingresó ninguna clave. Recuerda configurar GEMINI_API_KEY en tu ~/.zshrc."
    fi
  fi
fi

# ------------------------------------------------------------------------------
# 5. Permisos de ejecución del script de commit
# ------------------------------------------------------------------------------
COMMIT_SCRIPT="$REPO_LAZYGIT/scripts/gemini-commit.sh"
if [ -f "$COMMIT_SCRIPT" ]; then
  chmod +x "$COMMIT_SCRIPT"
  echo "✅ Permisos de ejecución verificados para gemini-commit.sh."
fi

# ------------------------------------------------------------------------------
# 6. Verificar herramientas del sistema
# ------------------------------------------------------------------------------
MISSING_TOOLS=()
command -v lazygit &>/dev/null || MISSING_TOOLS+=("lazygit")
command -v jq &>/dev/null || MISSING_TOOLS+=("jq")
command -v curl &>/dev/null || MISSING_TOOLS+=("curl")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
  echo "⚠️ Herramientas faltantes detectadas: ${MISSING_TOOLS[*]}"
  if command -v brew &>/dev/null; then
    echo "==> Instalando herramientas faltantes con Homebrew..."
    brew install "${MISSING_TOOLS[@]}"
  else
    echo "⚠️ Por favor instala manualmente: ${MISSING_TOOLS[*]}"
  fi
else
  echo "✅ Todas las herramientas necesarias (lazygit, jq, curl) están instaladas."
fi

echo "========================================================"
echo "🎉 ¡Configuración de LazyGit completada con éxito!"
echo "   Puedes iniciar lazygit y presionar <Ctrl-g> para commits automáticos."
echo "========================================================"
