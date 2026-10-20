local function refresh_workspace_git(state)
  local git = require "neo-tree.git"
  local utils = require "neo-tree.utils"
  local config = require("neo-tree").config

  require("neo-tree.sources.filesystem.commands").refresh(state)

  -- The default refresh only queries Git at the tree root. Existing nested
  -- repositories must be queried explicitly to replace their cached statuses.
  for repo_path in pairs(git.worktrees) do
    if utils.is_subpath(state.path, repo_path) or utils.is_subpath(repo_path, state.path) then
      git.status_async(repo_path, state.git_base_by_worktree, config.git_status_async_options)
    end
  end
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<leader>ge",
        "<cmd>Neotree toggle filesystem right<cr>",
        desc = "Git workspace explorer (Neo-tree)",
      },
    },
    opts = {
      sources = { "filesystem" },
      enable_git_status = true,
      git_status_async = true,
      default_component_configs = {
        git_status = {
          symbols = {
            staged = "S",
            unstaged = "U",
            untracked = "?",
            conflict = "!",
          },
        },
      },
      window = {
        position = "right",
        width = 52,
      },
      filesystem = {
        commands = {
          refresh_workspace_git = refresh_workspace_git,
        },
        window = {
          mappings = {
            ["R"] = "refresh_workspace_git",
          },
        },
        -- Keep the workspace root independent of the current file and NvimTree.
        bind_to_cwd = false,
        follow_current_file = { enabled = false },
        hijack_netrw_behavior = "disabled",
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_dotfiles = false,
          hide_gitignored = true,
          never_show = { ".git" },
        },
      },
    },
  },
}
