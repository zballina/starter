local function workspace_git_status(config, node, state)
  if node.type ~= "directory" or not vim.uv.fs_stat(node.path .. "/.git") then
    return require("neo-tree.sources.common.components").git_status(config, node, state)
  end

  local git = require "neo-tree.git"
  local repo_path = vim.uv.fs_realpath(node.path) or node.path
  state.workspace_git_roots = state.workspace_git_roots or {}
  if not state.workspace_git_roots[node.path] then
    state.workspace_git_roots[node.path] = repo_path
    -- Discover visible repositories without expanding or recursively scanning them.
    vim.schedule(function()
      local options = require("neo-tree").config.git_status_async_options
      git.status_async(repo_path, state.git_base_by_worktree, options)
    end)
  end

  local repo = git.worktrees[repo_path]
  for _, status in pairs(repo and repo.status or {}) do
    local codes = type(status) == "table" and status or { status }
    for _, code in ipairs(codes) do
      if code ~= "!" and code ~= "!!" and code ~= ".." and code ~= "" then
        return { text = "●", highlight = "NeoTreeGitModified" }
      end
    end
  end
  return {}
end

local function refresh_workspace_git(state)
  local git = require "neo-tree.git"
  local utils = require "neo-tree.utils"
  local config = require("neo-tree").config

  require("neo-tree.sources.filesystem.commands").refresh(state)

  -- The default refresh only queries Git at the tree root. Existing nested
  -- repositories must be queried explicitly to replace their cached statuses.
  local repo_paths = {}
  for repo_path in pairs(git.worktrees) do
    if utils.is_subpath(state.path, repo_path) or utils.is_subpath(repo_path, state.path) then
      repo_paths[repo_path] = true
    end
  end
  for node_path, repo_path in pairs(state.workspace_git_roots or {}) do
    if utils.is_subpath(state.path, node_path) then
      repo_paths[repo_path] = true
    end
  end
  for repo_path in pairs(repo_paths) do
    git.status_async(repo_path, state.git_base_by_worktree, config.git_status_async_options)
  end
end

return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    lazy = false,
    cmd = "Neotree",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "MunifTanjim/nui.nvim",
      "nvim-tree/nvim-web-devicons",
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
        position = "left",
        width = 52,
      },
      filesystem = {
        components = {
          git_status = workspace_git_status,
        },
        commands = {
          refresh_workspace_git = refresh_workspace_git,
        },
        window = {
          mappings = {
            ["R"] = "refresh_workspace_git",
          },
        },
        -- Keep the workspace root independent of the current file.
        bind_to_cwd = false,
        follow_current_file = { enabled = false },
        hijack_netrw_behavior = "open_default",
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
