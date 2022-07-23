-- set the color scheme
local ok, _ = pcall(vim.cmd, 'colorscheme seoul256-light')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
