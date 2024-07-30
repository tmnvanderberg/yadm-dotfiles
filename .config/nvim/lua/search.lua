require('map')

-- Fuzzy search for anything, really.
Map(
	"n",
	"<C-p>",
	":FzfLua<CR>",
	{ silent = true, noremap = true }
)

Map(
	"n",
	"<C-l>",
	":FzfLua buffers<CR>",
	{ silent = true, noremap = true }
)

-- search current word with with spectre
Map(
  "n",
  "<Leader>w",
  ":lua require('spectre').open_visual({select_word=true})<CR>",
  { silent = true, noremap = true }
)
-- search current selection with spectre
Map(
  "v",
  "<Leader>w",
  ":lua require('spectre').open_visual()<CR>",
  { silent = true, noremap = true }
)

require('spectre').setup({
  open_cmd = 'botright new',
  find_engine = {
    -- rg is map with finder_cmd
    ['rg'] = {
      cmd = "rg",
      -- default args
      args = {
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
      },
      options = {
        ['ignore-case'] = {
          value= "--ignore-case",
          icon="[I]",
          desc="ignore case"
        },
        ['hidden'] = {
          value="--hidden",
          desc="hidden file",
          icon="[H]"
        },
        ['no-ignore-vcs'] = {
          value="--no-ignore-vcs",
          desc="ignore gitignore",
          icon="[NIVCS]"
        },
        -- you can put any rg search option you want here it can toggle with
        -- show_option function
      }
    },
    ['ag'] = {
      cmd = "ag",
      args = {
        '--vimgrep',
        '-s'
      } ,
      options = {
        ['ignore-case'] = {
          value= "-i",
          icon="[I]",
          desc="ignore case"
        },
        ['hidden'] = {
          value="--hidden",
          desc="hidden file",
          icon="[H]"
        },
      },
    },
  },
})

