require('map')

-- Fuzzy search for anything, really. I used to have shortcuts for different searches, 
-- but this has less mental overhead and allows you to search with 1 or 2 letters
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
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

vim.api.nvim_create_user_command(
  'ListFilesFromBranch',
  function(opts)
    require 'fzf-lua'.files({
      cmd = "git ls-tree -r --name-only " .. opts.args,
      prompt = opts.args .. "> ",
      actions = {
        ['default'] = false,
        ['ctrl-s'] = false,
        ['ctrl-v'] = function(selected, o)
          local file = require'fzf-lua'.path.entry_to_file(selected[1], o)
          local cmd = string.format("Gvsplit %s:%s", opts.args, file.path)
          vim.cmd(cmd)
        end,
      },
      previewer = false,
      preview = require'fzf-lua'.shell.raw_preview_action_cmd(function(items)
        local file = require'fzf-lua'.path.entry_to_file(items[1])
        return string.format("git diff %s HEAD -- %s | delta", opts.args, file.path)
      end)
    })
  end,
  {
    nargs = 1,
    force = true,
    complete = function()
      local branches = vim.fn.systemlist("git branch --all --sort=-committerdate")
      if vim.v.shell_error == 0 then
        return vim.tbl_map(function(x)
          return x:match("[^%s%*]+"):gsub("^remotes/", "")
        end, branches)
      end
    end,
  })

