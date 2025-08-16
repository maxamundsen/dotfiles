-- Max Amundsen's Neovim Config
vim.opt.number = true
vim.opt.relativenumber = true  -- Show relative line numbers
vim.opt.tabstop = 4            -- Number of spaces a tab counts for
vim.opt.shiftwidth = 4         -- Number of spaces for each indent
vim.opt.expandtab = true       -- Convert tabs to spaces
vim.opt.autoindent = true      -- Copy indent from current line when starting new line
vim.opt.ignorecase = true      -- Case insensitive searching
vim.opt.smartcase = true       -- Case sensitive when search contains uppercase
vim.opt.hlsearch = false        -- Highlight search results
vim.opt.incsearch = true       -- Show matches while typing
vim.opt.cursorline = false      -- Highlight current line
vim.opt.showmatch = true       -- Highlight matching brackets
-- vim.opt.termguicolors = true   -- Enable 24-bit RGB colors
vim.opt.scrolloff = 8          -- Keep 8 lines visible above/below cursor
vim.opt.mouse = 'a'            -- Enable mouse in all modes
vim.opt.clipboard = 'unnamedplus'  -- Use system clipboard
vim.opt.undofile = true        -- Persistent undo
vim.opt.swapfile = false       -- Disable swap files
vim.opt.formatoptions:remove('r')
vim.g.mapleader = ' '          -- Set leader key to space
vim.opt.wrap = false

-- KEYMAPS
vim.keymap.set('n', '<leader>w', ':w<CR>')
vim.keymap.set('n', '<leader>q', ':q<CR>')
vim.keymap.set('n', '<leader>e', ':Explore<CR>')
vim.keymap.set("i", "<C-c>", "<Esc>")
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]])
vim.keymap.set("n", "<leader>n", ":e ~/.config/nvim/init.lua<CR>")
vim.keymap.set("n", "<leader>a", "<Esc>ggVG")
vim.keymap.set("n", "<leader>v", ":vs<cr><C-w>l")
vim.keymap.set("n", "<leader>h", ":sp<cr><C-w>j")

vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")

vim.keymap.set("n", "<leader>1", "<C-w>h")
vim.keymap.set("n", "<leader>2", function()
    if vim.fn.winnr('$') == 1 then
        vim.cmd('vs')
        vim.cmd('wincmd l')
    else
        vim.cmd('wincmd l')
    end
end)

local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>p', builtin.git_files, { desc = 'Telescope: Git find files' })
vim.keymap.set('n', '<leader>f', builtin.current_buffer_fuzzy_find, { desc = 'Telescope: Fuzzy find in file' })

-- appearance

