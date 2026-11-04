return {
  {
    "nvim-tree/nvim-tree.lua",
    lazy = false,
    opts = function()
      local opts = require "nvchad.configs.nvimtree"
      local workspace_git = require "configs.tree_git"

      return vim.tbl_deep_extend("force", opts, {
        sync_root_with_cwd = false,
        actions = { change_dir = { enable = false } },
        update_focused_file = { enable = false, update_root = false },
        view = { side = "left", width = 52 },
        filters = { dotfiles = false, git_ignored = true, custom = { "^\\.git$" } },
        git = { enable = true, show_on_dirs = true, show_on_open_dirs = true },
        filesystem_watchers = { enable = true },
        renderer = {
          highlight_git = "name",
          decorators = {
            "Git", "Open", "Hidden", "Modified", "Bookmark", "Diagnostics", "Copied",
            workspace_git.Decorator, "Cut",
          },
          icons = {
            show = { git = true },
            glyphs = { git = { staged = "S", unstaged = "U", untracked = "?", unmerged = "!" } },
          },
        },
        on_attach = function(bufnr)
          local api = require "nvim-tree.api"
          api.map.on_attach.default(bufnr)
          local function map(key, callback, description)
            vim.keymap.set("n", key, callback, {
              buffer = bufnr, silent = true, nowait = true, desc = description,
            })
          end
          map("R", workspace_git.refresh, "Refresh tree and workspace Git")
          map("?", api.tree.toggle_help, "Help")
        end,
      })
    end,
    config = function(_, opts)
      require("nvim-tree").setup(opts)
      require("configs.tree_git").setup()
    end,
  },
}
