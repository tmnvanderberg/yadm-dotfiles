-- set the color scheme
vim.cmd [[ set background=light ]]
vim.cmd [[ set termguicolors ]]
local ok, _ = pcall(vim.cmd, 'colorscheme peachpuff')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
