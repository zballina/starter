#!/usr/bin/env bash
set -e

echo "==> Verificando dependencias del sistema..."

# Si estás en macOS con Homebrew
if command -v brew &>/dev/null; then
  echo "==> Instalando herramientas base con Homebrew..."
  brew install neovim ripgrep fd nodejs gcc
fi

# Instalar dependencias de markdown-preview de antemano si existe
MKDP_DIR="$HOME/.local/share/nvim/lazy/markdown-preview.nvim/app"
if [ -d "$MKDP_DIR" ]; then
  echo "==> Instalando dependencias de markdown-preview..."
  cd "$MKDP_DIR" && npm install
fi

echo "==> Sincronizando plugins de Neovim..."
# Ejecuta lazy sync de forma no interactiva
nvim --headless "+Lazy! sync" +qa

echo "==> ¡Configuración completada con éxito!"
