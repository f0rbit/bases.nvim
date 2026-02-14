vim.filetype.add({ extension = { base = "base" } })
vim.api.nvim_create_autocmd("FileType", {
  pattern = "base",
  callback = function()
    require("bases").attach()
  end,
})
