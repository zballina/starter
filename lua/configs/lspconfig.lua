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
  "gopls",
}

-- Función para que Pyright auto-detecte rutas locales de Lambdas y .venv
local function pyright_before_init(_, config)
  local file_dir = vim.fn.expand "%:p:h"
  local root = config.root_dir or vim.fn.getcwd()

  config.settings = config.settings or {}
  config.settings.python = config.settings.python or {}
  config.settings.python.analysis = config.settings.python.analysis or {}

  -- 1. Inyecta la carpeta del archivo abierto para resolver imports locales directos
  local paths = { root }
  if file_dir ~= "" and vim.fn.isdirectory(file_dir) == 1 then
    table.insert(paths, file_dir)
  end
  config.settings.python.analysis.extraPaths = paths

  -- 2. Busca automáticamente un .venv / venv hacia arriba en el árbol de carpetas
  local venv = vim.fs.find({ ".venv", "venv" }, {
    path = file_dir ~= "" and file_dir or root,
    upward = true,
    type = "directory",
  })[1]

  if venv and vim.fn.isdirectory(venv) == 1 then
    config.settings.python.pythonPath = venv .. "/bin/python"
  end
end

-- Configuración limpia usando vim.lsp (evita el deprecation warning de lspconfig)
for _, lsp in ipairs(servers) do
  local opts = {
    on_attach = nvlsp.on_attach,
    on_init = nvlsp.on_init,
    capabilities = nvlsp.capabilities,
  }

  -- Inyectar configuración específica para Pyright
  if lsp == "pyright" then
    opts.before_init = pyright_before_init
    opts.settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          useLibraryCodeForTypes = true,
          diagnosticMode = "openFilesOnly",
        },
      },
    }
  end

  if vim.lsp and vim.lsp.config and vim.lsp.enable then
    -- API nativa de Neovim
    vim.lsp.config[lsp] = opts
    vim.lsp.enable(lsp)
  else
    -- Fallback para lspconfig clásico
    local lspconfig = require "lspconfig"
    lspconfig[lsp].setup(opts)
  end
end
