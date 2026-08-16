-- Cargar los defaults de NvChad (diagnósticos, floating windows, bordes)
require("nvchad.configs.lspconfig").defaults()

local nvlsp = require "nvchad.configs.lspconfig"

local servers = {
  "html",
  "cssls",
  "ts_ls",
  "pyright",
  "bashls",
  "dockerls",
  "yamlls",
  "lua_ls",
}

-- Configuración limpia usando vim.lsp (evita el deprecation warning de lspconfig)
for _, lsp in ipairs(servers) do
  if vim.lsp and vim.lsp.config and vim.lsp.enable then
    -- API nativa de Neovim 0.11+
    vim.lsp.config[lsp] = {
      cmd = nil,
      on_attach = nvlsp.on_attach,
      on_init = nvlsp.on_init,
      capabilities = nvlsp.capabilities,
    }
    vim.lsp.enable(lsp)
  else
    -- Fallback para versiones anteriores usando lspconfig clásico
    local lspconfig = require "lspconfig"
    lspconfig[lsp].setup {
      on_attach = nvlsp.on_attach,
      on_init = nvlsp.on_init,
      capabilities = nvlsp.capabilities,
    }
  end
end
