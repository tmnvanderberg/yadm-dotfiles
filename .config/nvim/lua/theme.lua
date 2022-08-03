-- set the color scheme
vim.cmd [[ set background=dark ]]
local ok, _ = pcall(vim.cmd, 'colorscheme everforest')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
