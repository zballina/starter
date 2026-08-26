require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

-- Alternar renderizado Markdown en el buffer de Neovim
map("n", "<Space>mr", "<cmd>RenderMarkdown toggle<cr>", { desc = "Toggle Render Markdown" })

-- Mantener la selección al indentar en modo visual
map("v", ">", ">gv", { desc = "Aumentar indentación y mantener selección" })
map("v", "<", "<gv", { desc = "Disminuir indentación y mantener selección" })

-- Función para abrir LazyGit en una ventana flotante nativa con su propio CWD
local function open_lazygit_floating(repo_path)
  -- 1. Crear un buffer scratch limpio
  local buf = vim.api.nvim_create_buf(false, true)

  -- 2. Dimensiones de la ventana flotante (Ajustadas a 95% ancho x 100% alto)
  local width = math.floor(vim.o.columns * 0.95)
  local height = math.floor(vim.o.lines * 1)
  local col = math.floor((vim.o.columns - width) / 2)
  local row = math.floor((vim.o.lines - height) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
  })

  -- 3. Lanzar lazygit con el cwd fijado directamente al sub-repo seleccionado
  vim.fn.termopen("lazygit", {
    cwd = repo_path,
    on_exit = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })

  vim.cmd("startinsert")
end

-- Helper para escanear repositorios en el workspace
local function get_workspace_repos()
  local main_cwd = vim.fn.getcwd()
  local repos = {}

  if vim.uv.fs_stat(main_cwd .. "/.git") then
    table.insert(repos, main_cwd)
  end

  local handle = io.popen("find . -maxdepth 3 -name .git -type d 2>/dev/null")
  if handle then
    for line in handle:lines() do
      local repo_rel = line:gsub("/%.git$", "")
      local repo_full = (repo_rel == ".") and main_cwd or (main_cwd .. "/" .. repo_rel:gsub("^%./", ""))
      local exists = false
      for _, r in ipairs(repos) do
        if r == repo_full then
          exists = true
          break
        end
      end
      if not exists then
        table.insert(repos, repo_full)
      end
    end
    handle:close()
  end
  return repos
end

-- Atajo <leader>gg
map("n", "<leader>gg", function()
  -- Auto-guardar buffer actual si es un archivo normal modificado
  if vim.bo.modified and vim.bo.buftype == "" then
    vim.cmd("silent! write")
  end

  local main_cwd = vim.fn.getcwd()
  local repos = get_workspace_repos()

  -- Si solo hay un repo o ninguno, abrir directo
  if #repos <= 1 then
    open_lazygit_floating(repos[1] or main_cwd)
    return
  end

  -- Mostrar siempre la lista interactiva con Telescope
  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local action_state = require("telescope.actions.state")

  pickers.new({}, {
    prompt_title = "Selecciona Repositorio Git",
    finder = finders.new_table({
      results = repos,
      entry_maker = function(entry)
        local display_name = entry:gsub("^" .. vim.pesc(main_cwd .. "/"), "")
        return {
          value = entry,
          display = (display_name == entry) and "[Raíz] " .. display_name or "📁 " .. display_name,
          ordinal = display_name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          open_lazygit_floating(selection.value)
        end
      end)
      return true
    end,
  }):find()
end, { desc = "LazyGit (Selector de repositorios)" })
