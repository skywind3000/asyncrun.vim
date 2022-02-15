local terminal = require("toggleterm.terminal").Terminal
local config = require("toggleterm.config")
local M = {}

function M.reset()
  if M._asyncrun_term ~= nil then
    if vim.g.asynctasks_term_reuse ~= 1 then
      -- TODO: handle multiple terminals
      error("Terminal existed")
    else
      vim.notify("Delete existing terminal", "info")
    end
    M._asyncrun_term:shutdown()
    vim.api.nvim_del_keymap("n", M._asyncrun_mapping)
  end

  M._asyncrun_term = nil
  M._asyncrun_term_toggle = nil
  M._asyncrun_mapping = nil
end

function M.runner(opts, mapping)
  M.reset()
  M._asyncrun_term = terminal:new({
    cmd = opts.cmd,
    dir = opts.cwd,
    close_on_exit = false,
    hidden = true,
  })

  function M._asyncrun_term_toggle()
    M._asyncrun_term:toggle()
  end

  if not opts.silent then
    M._asyncrun_term_toggle()
  end
  M._asyncrun_mapping = mapping or config.get("open_mapping")
  if M._asyncrun_mapping then
    vim.api.nvim_set_keymap(
      "n",
      M._asyncrun_mapping,
      "<cmd>lua require('asyncrun.toggleterm')._asyncrun_term_toggle()<CR>",
      { noremap = true, silent = true }
    )
  end
end

return M
