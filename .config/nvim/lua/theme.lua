-- set the color scheme
vim.cmd [[ set background=dark ]]
vim.cmd [[ set termguicolors ]]
local ok, _ = pcall(vim.cmd, 'colorscheme gruvbox-material')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
