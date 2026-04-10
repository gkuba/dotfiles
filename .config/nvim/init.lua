-- =============================================
-- Basic Settings (converted from your .vimrc)
-- =============================================
vim.opt.termguicolors = true      -- Enable true color support
vim.opt.encoding = "utf-8"
vim.opt.laststatus = 2
vim.opt.history = 1000
vim.opt.cursorline = true
vim.opt.wrap = false
vim.opt.number = true
vim.opt.compatible = false

-- Search / Completion
vim.opt.path:append("**")
vim.opt.wildmenu = true
vim.opt.wildmode = "list:longest,full"

-- Syntax & plugins
vim.cmd("syntax enable")
vim.cmd("filetype plugin on")

-- =============================================
-- Plugin Manager: lazy.nvim
-- =============================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- =============================================
-- Plugins
-- =============================================
require("lazy").setup({
  -- Colorscheme
  {
    "Mofiqul/dracula.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require("dracula").setup({
        transparent_bg = false,   -- change to true if you want transparency
      })
      vim.cmd("colorscheme dracula")
    end,
  },

  -- Statusline (replaces vim-airline)
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = {
          theme = "dracula",
          section_separators = { left = "", right = "" },
          component_separators = { left = "", right = "" },
        },
      })
    end,
  },

  -- File explorer (replaces NERDTree)
  {
    "nvim-tree/nvim-tree.lua",
    version = "*",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        sort_by = "case_sensitive",
        view = {
          width = 35,
          side = "left",
        },
        renderer = {
          group_empty = true,
          icons = {
            show = {
              file = true,
              folder = true,
              folder_arrow = true,
            },
          },
        },
        filters = {
          dotfiles = false,
        },
      })

      -- Auto open nvim-tree when no files are specified (like your NERDTree)
      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          if vim.fn.argc() == 0 then
            require("nvim-tree.api").tree.open()
          end
        end,
      })
    end,
  },

  -- Git integration (your vim-fugitive)
  "tpope/vim-fugitive",

  -- Optional: Better icons (highly recommended)
  "nvim-tree/nvim-web-devicons",
})

-- =============================================
-- Key Mappings (same as your .vimrc)
-- =============================================
vim.keymap.set("n", "<C-J>", "<C-W><C-J>", { noremap = true })
vim.keymap.set("n", "<C-K>", "<C-W><C-K>", { noremap = true })
vim.keymap.set("n", "<C-L>", "<C-W><C-L>", { noremap = true })
vim.keymap.set("n", "<C-H>", "<C-W><C-H>", { noremap = true })

-- Extra useful mappings for nvim-tree
vim.keymap.set("n", "<leader>e", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
