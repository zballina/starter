local api = require "nvim-tree.api"
local M = {}
local repositories = {}
local expanded_repositories = {}
local visible_repositories = {}
local redraw_pending = false

local function redraw()
  if redraw_pending then
    return
  end
  redraw_pending = true
  vim.defer_fn(function()
    redraw_pending = false
    if api.tree.is_visible() then
      api.tree.reload()
    end
  end, 50)
end

local query_status
query_status = function(path, repository)
  if repository.running then
    repository.refresh_pending = true
    return
  end
  repository.running = true
  -- Argument arrays handle spaces in paths. Disable optional index writes.
  vim.system({
    "git", "--no-optional-locks", "-C", path, "status", "--porcelain=v1",
    "--untracked-files=normal", "--ignore-submodules=none",
  }, { text = true, timeout = 10000 }, vim.schedule_wrap(function(result)
    repository.running = false
    if result.code == 0 then
      local dirty = result.stdout ~= ""
      repository.failed = false
      if dirty ~= repository.dirty then
        repository.dirty = dirty
        redraw()
      end
    elseif not repository.failed then
      repository.failed = true
      vim.notify("Could not refresh Git status for " .. path .. ": " .. (result.stderr or ""), vim.log.levels.WARN)
    end
    if repository.refresh_pending then
      repository.refresh_pending = false
      query_status(path, repository)
    end
  end))
end

-- Only the directories being rendered are inspected; closed folders are not traversed.
local WorkspaceGit = api.Decorator:extend()
function WorkspaceGit:new()
  self.enabled = true
  self.highlight_range = "all"
  self.icon_placement = "after"
  visible_repositories = {}
end

function WorkspaceGit:highlight_group(node)
  if node.type ~= "directory" or not vim.uv.fs_stat(node.absolute_path .. "/.git") then
    return
  end
  local path = vim.uv.fs_realpath(node.absolute_path) or node.absolute_path
  if repositories[path] and repositories[path].dirty then
    return "NvimTreeGitDirtyIcon"
  end
end

function WorkspaceGit:icons(node)
  if node.type ~= "directory" or not vim.uv.fs_stat(node.absolute_path .. "/.git") then
    return
  end
  -- .git can be a directory or a file (worktrees and submodules).
  local path = vim.uv.fs_realpath(node.absolute_path) or node.absolute_path
  visible_repositories[path] = true
  if node.open and not expanded_repositories[path] and not require("nvim-tree.git").get_project(path) then
    expanded_repositories[path] = true
    vim.schedule(function()
      -- Compatibility with the pinned nvim-tree revision: reloading a workspace
      -- can populate a closed repo before native Git discovery runs. Register
      -- expanded repos so native file indicators are retained after refreshes.
      local project = require("nvim-tree.git").load_project(path)
      expanded_repositories[path] = nil
      if next(project) then
        redraw()
      end
    end)
  end
  local repository = repositories[path]
  if not repository then
    repository = { dirty = false }
    repositories[path] = repository
    -- The renderer must not be re-entered by a process callback.
    vim.schedule(function()
      query_status(path, repository)
    end)
  end
  if repository.dirty then
    return { { str = "●", hl = { "NvimTreeGitDirtyIcon" } } }
  end
end

M.Decorator = WorkspaceGit

function M.refresh()
  if not api.tree.is_visible() then
    return
  end
  api.tree.reload()
  for path in pairs(visible_repositories) do
    query_status(path, repositories[path])
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("NvimTreeWorkspaceGit", { clear = true })
  local refresh_generation = 0
  local function schedule_refresh()
    refresh_generation = refresh_generation + 1
    local generation = refresh_generation
    vim.defer_fn(function()
      if generation == refresh_generation then
        M.refresh()
      end
    end, 300)
  end

  vim.api.nvim_create_autocmd({ "FocusGained", "BufWritePost" }, { group = group, callback = schedule_refresh })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "WorkspaceGitRefresh",
    callback = schedule_refresh,
  })
  vim.api.nvim_create_autocmd("TermClose", {
    group = group,
    callback = function(args)
      if vim.api.nvim_buf_get_name(args.buf):lower():find("lazygit", 1, true) then
        schedule_refresh()
      end
    end,
  })
  api.events.subscribe(api.events.Event.TreeOpen, schedule_refresh)
end

return M
