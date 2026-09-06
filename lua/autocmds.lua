require "nvchad.autocmds"

-- Atajo para confirmar commit de Gemini con ENTER en Modo Normal
vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
  pattern = "*gemini_commit_msg*",
  callback = function(args)
    vim.bo[args.buf].filetype = "gitcommit"

    -- ENTER en modo Normal: Guarda y confirma el commit (:wq)
    vim.keymap.set("n", "<CR>", "<cmd>wq<CR>", {
      buffer = args.buf,
      silent = true,
      desc = "Confirmar commit con ENTER",
    })
  end,
})
