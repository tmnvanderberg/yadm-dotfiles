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
					local file = require 'fzf-lua'.path.entry_to_file(selected[1], o)
					local cmd = string.format("Gvsplit %s:%s", opts.args, file.path)
					vim.cmd(cmd)
				end,
			},
			previewer = false,
			preview = require 'fzf-lua'.shell.raw_preview_action_cmd(function(items)
				local file = require 'fzf-lua'.path.entry_to_file(items[1])
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
