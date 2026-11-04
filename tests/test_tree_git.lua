-- Run from the config root with NVIM_APPNAME=nvim-nvchad nvim --headless -u NONE -i NONE -l tests/test_tree_git.lua
local root = vim.fn.getcwd()
local plugin_root = vim.fn.stdpath "data" .. "/lazy/"
vim.opt.rtp:prepend(root)
vim.opt.rtp:append(plugin_root .. "nvim-tree.lua")
vim.opt.rtp:append(plugin_root .. "NvChad")
vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"

local api = require "nvim-tree.api"
local workspace_git = require "configs.tree_git"
local spec = require("plugins.nvim-tree")[1]
local fixture = vim.fn.tempname() .. " workspace"
vim.fn.mkdir(fixture, "p")
fixture = assert(vim.uv.fs_realpath(fixture))
local states, calls, completed = {}, {}, {}
local original_system = vim.system
local warnings = {}
local original_notify = vim.notify
vim.notify = function(message, level)
  if level == vim.log.levels.WARN then
    warnings[#warnings + 1] = message
  else
    original_notify(message, level)
  end
end

-- These are directory fixtures, not real repositories. No Git state is mutated.
local function make_repository(name, status, git_file)
  local path = fixture .. "/" .. name
  vim.fn.mkdir(path, "p")
  if git_file then
    vim.fn.writefile({ "gitdir: /unused/test-fixture" }, path .. "/.git")
  else
    vim.fn.mkdir(path .. "/.git")
  end
  states[path] = { code = 0, stdout = status, stderr = "" }
  return path
end

local dirty_path = make_repository("dirty repo", " M file.lua\n")
local clean_path = make_repository("clean repo", "")
local worktree_path = make_repository("linked worktree", "?? new.lua\n", true)
local nested_path = make_repository("container/nested repo", "A  added.lua\n")
vim.fn.writefile({ "file" }, dirty_path .. "/file.lua")
vim.system = function(command, options, callback)
  if command[1] ~= "git" or command[2] ~= "--no-optional-locks" then
    return original_system(command, options, callback)
  end
  local path = command[4]
  calls[path] = (calls[path] or 0) + 1
  local result = vim.deepcopy(assert(states[path], path))
  vim.defer_fn(function()
    completed[path] = (completed[path] or 0) + 1
    callback(result)
  end, 10)
end

local function tree_buffer()
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if api.tree.is_tree_buf(bufnr) then
      return bufnr
    end
  end
  error("Missing tree buffer")
end

local function tree_lines()
  return vim.api.nvim_buf_get_lines(tree_buffer(), 0, -1, false)
end

local function marked(name)
  for _, line in ipairs(tree_lines()) do
    if line:find(name, 1, true) and line:find("●", 1, true) then
      return true
    end
  end
  return false
end

local function wait_for(predicate, message)
  assert(vim.wait(3000, predicate, 20), message)
end

local function top_node(name)
  for _, node in ipairs(api.tree.get_nodes().nodes) do
    if node.name == name then
      return node
    end
  end
  error("Missing node " .. name)
end

local function expand(name)
  for line_number, line in ipairs(tree_lines()) do
    local name_position = line:find(name, 1, true)
    local link_position = line:find("➛", 1, true)
    if name_position and (not link_position or name_position < link_position) then
      vim.api.nvim_win_set_cursor(0, { line_number, 0 })
      api.node.open.edit()
      return
    end
  end
  error("Missing directory " .. name)
end

local function run()
  local opts = spec.opts()
  assert(opts.git.enable and opts.git.show_on_dirs)
  assert(not opts.update_focused_file.enable and not opts.actions.change_dir.enable)
  -- Native Git is tested separately below against the existing real repository.
  opts.git.enable = false
  opts.filesystem_watchers.enable = false
  spec.config(nil, opts)
  api.tree.open { path = fixture }
  wait_for(function()
    return marked("dirty repo") and marked("linked worktree")
  end, "Collapsed repository and worktree must show pending changes")
  assert(not marked("clean repo"), "Clean repository must not have a mark")
  assert(not calls[nested_path], "Closed containers must not be recursively inspected")
  assert(vim.fn.getcwd() == root, "Tree navigation must preserve cwd")
  assert(not top_node("dirty repo").open, "Git discovery must not expand repositories")

  for _, status in ipairs({ "M  file.lua\n", "MM file.lua\n", "?? new.lua\n", "UU file.lua\n" }) do
    local previous_calls = calls[clean_path]
    states[clean_path].stdout = status
    workspace_git.refresh()
    wait_for(function()
      return calls[clean_path] > previous_calls and completed[clean_path] == calls[clean_path] and marked("clean repo")
    end, "Staged, unstaged, untracked, and conflicting changes must have marks")
  end

  states[dirty_path].stdout = ""
  states[clean_path].stdout = ""
  vim.api.nvim_exec_autocmds("User", { pattern = "WorkspaceGitRefresh" })
  wait_for(function()
    return not marked("dirty repo") and not marked("clean repo")
  end, "Refresh after LazyGit must clear marks when repositories become clean")

  states[dirty_path].stdout = " M file.lua\n"
  vim.api.nvim_exec_autocmds("FocusGained", {})
  wait_for(function()
    return marked("dirty repo")
  end, "FocusGained must refresh Git state")
  states[dirty_path].stdout = ""
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = 0 })
  wait_for(function()
    return not marked("dirty repo")
  end, "Saving a file must refresh Git state")

  states[dirty_path].stdout = " M file.lua\n"
  local terminal = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(terminal, "term://test//lazygit")
  vim.v.errmsg = ""
  vim.api.nvim_exec_autocmds("TermClose", { buffer = terminal, data = { status = 0 } })
  assert(vim.v.errmsg == "", vim.v.errmsg)
  wait_for(function()
    return marked("dirty repo")
  end, "Closing a LazyGit terminal must refresh Git state")
  vim.api.nvim_buf_delete(terminal, { force = true })

  api.tree.close()
  states[dirty_path].stdout = ""
  api.tree.open { path = fixture }
  wait_for(function()
    return not marked("dirty repo")
  end, "Reopening the tree must refresh previously cached repositories")

  states[worktree_path] = { code = 128, stdout = "", stderr = "simulated failure" }
  workspace_git.refresh()
  wait_for(function()
    return #warnings > 0
  end, "Git failures must be reported")
  assert(marked("linked worktree"), "Failed status must not silently mark a repository clean")
  states[worktree_path] = { code = 0, stdout = "", stderr = "" }
  workspace_git.refresh()
  wait_for(function()
    return not marked("linked worktree")
  end, "Git queries must recover after failures")

  expand "container"
  wait_for(function()
    return marked("nested repo")
  end, "Expanding a container must discover nested repositories")

  local mappings = vim.api.nvim_buf_get_keymap(tree_buffer(), "n")
  local found_refresh = false
  for _, mapping in ipairs(mappings) do
    if mapping.lhs == "R" then
      found_refresh = mapping.callback == workspace_git.refresh
    end
  end
  assert(found_refresh, "R must refresh both the tree and workspace Git")

  -- Exercise the actual Git command and native file statuses using read-only Git.
  vim.system = original_system
  local real_status = vim.system({
    "git", "--no-optional-locks", "-C", root, "status", "--porcelain=v1", "--untracked-files=normal",
  }, { text = true }):wait()
  assert(real_status.code == 0)
  local real_dirty = real_status.stdout ~= ""
  opts.git.enable = true
  require("nvim-tree").setup(opts)
  assert(require("nvim-tree.config").g.git.enable, "Native Git config must be enabled")
  api.tree.open { path = vim.fn.fnamemodify(root, ":h") }
  wait_for(function()
    return marked(vim.fn.fnamemodify(root, ":t")) == real_dirty
  end, "Repository mark must agree with real Git status")
  expand(vim.fn.fnamemodify(root, ":t"))
  local function has_git_status(nodes)
    for _, node in ipairs(nodes) do
      if node.git_status and (node.git_status.file or node.git_status.dir) then
        return true
      end
      if node.nodes and has_git_status(node.nodes) then
        return true
      end
    end
    return false
  end
  wait_for(function()
    return require("nvim-tree.git").get_project(root) ~= nil
      and has_git_status({ api.tree.get_nodes() }) == real_dirty
  end, "Expanded repositories must retain native Git status after workspace refreshes")
  workspace_git.refresh()
  assert(has_git_status({ api.tree.get_nodes() }) == real_dirty, "Refreshing must preserve native Git indicators")
end

local success, failure = xpcall(run, debug.traceback)
vim.system = original_system
vim.notify = original_notify
api.tree.close()
vim.fn.delete(fixture, "rf")
assert(success, failure)
print("PASS: workspace Git indicators, refresh events, worktrees, nested repositories, and native Git statuses")
