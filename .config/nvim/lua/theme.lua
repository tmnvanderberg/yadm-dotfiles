-- set the color scheme
vim.cmd [[ set termguicolors ]]
vim.cmd [[ set background=dark]]
local ok, _ = pcall(vim.cmd, 'colorscheme tempus_night')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
