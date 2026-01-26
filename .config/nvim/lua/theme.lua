-- set the color scheme
vim.opt.termguicolors = true
vim.opt.background = "dark"
local ok, _ = pcall(vim.cmd, 'colorscheme gruvbox-material')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
