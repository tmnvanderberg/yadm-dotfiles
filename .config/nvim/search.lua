-- Functional wrapper for mapping custom keybindings
function map(mode, lhs, rhs, opts)
    local options = { noremap = true }
    if opts then
        options = vim.tbl_extend("force", options, opts)
    end
    vim.api.nvim_set_keymap(mode, lhs, rhs, options)
end

map("n", "<C-p>", ":FzfLua files<CR>", { silent = true })
map("n", "<Leader>b", ":FzfLua oldfiles<CR>", { silent = true })
map("n", "<Leader>m", ":FzfLua marks<CR>", { silent = true })
map("n", "<Leader>F", ":FzfLua grep_cword<CR>", { silent = true })
map("v", "<Leader>F", ":FzfLua grep_visual<CR>", { silent = true })
