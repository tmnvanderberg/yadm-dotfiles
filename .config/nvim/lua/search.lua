require('map')

-- Fuzzy search for anything, really. I used to have shortcuts for different searches, 
-- but this has less mental overhead and allows you to search with 1 or 2 letters
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true }
)

Map(
	"v",
	"<C-p>",
	"<Esc>:FzfLua<CR>",
	{ silent = true }
)

-- search with spectre
Map(
	"n",
	"<Leader><C-R>",
	"<cmd>lua require('spectre').open()<CR>",
	{ silent = true }
)

 function WatsonSwitchProject()
	require'fzf-lua'.fzf_exec("watson projects", {
		 actions = {
			['default'] = function(selected, opts)
				vim.cmd(":!watson start " .. selected[1])
			end
		 }
	})
end

function WatsonReport()
	local buf = vim.api.nvim_create_buf(false, true)
	-- vim.api.nvim_buf_set_lines(buf, 0, -1, true, {"test", "text"})
	local handle = io.popen("watson report --all --no-pager")
	if handle ~= nil then
		local result = handle:read("*a")
		vim.api.nvim_buf_set_text(buf, 0, 0, 0, 0, result)
		handle:close()
	end
	local opts = {
	    	relative = 'editor',
		width = 50,
		height = 50,
		col = 100,
		row = 50,
		anchor = 'NW',
		border = "single",
	}
	local win = vim.api.nvim_open_win(buf, 0, opts)
end

function WatsonCommands()
	require'fzf-lua'.fzf_exec(
		{"status", "start", "stop", "log", "aggregate", "report", "cancel"},
		{
			 actions = {
				['default'] = function(selected, opts)
					local cmd = selected[1]
					if 	cmd == "stop" 		then 	vim.cmd(":!watson stop")
					elseif 	cmd == "start" 		then 	WatsonSwitchProject()
					elseif  cmd == "status" 	then 	vim.cmd(":!watson status")
					elseif 	cmd == "log" 		then 	vim.cmd(":new | 0read ! watson log --all --no-pager")
					elseif 	cmd == "aggregate" 	then 	vim.cmd(":new | 0read ! watson aggregate --no-pager")
					elseif 	cmd == "report" 	then 	WatsonReport()	
					elseif 	cmd == "cancel" 	then 	vim.cmd(":new | 0read ! watson cancel")
					end
				end
			}
		}
	)
end

Map(
	"n",
	"<Leader>wt",
	":lua WatsonCommands()<CR>",
	{ silent = false }
)

