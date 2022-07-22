-- set the color scheme
local ok, _ = pcall(vim.cmd, 'colorscheme seoul256')
if not ok then
	vim.cmd [[ colorscheme default ]]
end
