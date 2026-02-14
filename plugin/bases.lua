-- Register filetype (idempotent — lazy.nvim users also do this in init)
vim.filetype.add({ extension = { base = "base" } })

-- FileType autocmd for .base files (backup trigger if not using BufReadCmd)
vim.api.nvim_create_autocmd("FileType", {
  pattern = "base",
  callback = function()
    require("bases").attach()
  end,
})
