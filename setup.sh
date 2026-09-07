#!/usr/bin/env bash
set -e

echo "==> Verificando dependencias del sistema..."

# ------------------------------------------------------------------------------
# 1. Validar herramientas del sistema e instalar solo las faltantes
# ------------------------------------------------------------------------------
REQUIRED_TOOLS=("nvim:neovim" "rg:ripgrep" "fd:fd" "node:nodejs" "gcc:gcc")
MISSING_BREW=()

for item in "${REQUIRED_TOOLS[@]}"; do
  cmd="${item%%:*}"
  pkg="${item##*:}"
  if ! command -v "$cmd" &>/dev/null; then
    MISSING_BREW+=("$pkg")
  fi
done

if [ ${#MISSING_BREW[@]} -gt 0 ]; then
  if command -v brew &>/dev/null; then
    echo "==> Instalando herramientas faltantes con Homebrew: ${MISSING_BREW[*]}..."
    brew install "${MISSING_BREW[@]}"
  else
    echo "⚠️ Homebrew no está instalado. Por favor instala manualmente: ${MISSING_BREW[*]}"
  fi
else
  echo "✅ Todas las herramientas base (neovim, ripgrep, fd, nodejs, gcc) ya están instaladas."
fi

# ------------------------------------------------------------------------------
# 2. Dependencias de markdown-preview (solo si no se han instalado antes)
# ------------------------------------------------------------------------------
for mkdp_base in "$HOME/.local/share/nvim" "$HOME/.local/share/nvim-nvchad"; do
  MKDP_DIR="$mkdp_base/lazy/markdown-preview.nvim/app"
  if [ -d "$MKDP_DIR" ] && [ ! -d "$MKDP_DIR/node_modules" ]; then
    echo "==> Instalando dependencias de markdown-preview en $MKDP_DIR..."
    (cd "$MKDP_DIR" && npm install)
  fi
done

echo "==> Sincronizando plugins de Neovim..."
# Ejecuta lazy sync de forma no interactiva
nvim --headless "+Lazy! sync" +qa

# Configuración de LazyGit con Gemini
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/setup_lazygit.sh" ]; then
  bash "$SCRIPT_DIR/setup_lazygit.sh"
fi

echo "==> ¡Configuración completada con éxito!"
