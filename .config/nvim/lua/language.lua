local map = require('map')

-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Mason handles installation of the language servers for nvim-lsp
require("mason").setup()
require("mason-lspconfig").setup({
	automatic_installation = true
})

local set_buffer_maps = function(_, bufnr)
  vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'
	vim.keymap.set('n', '<space>rd', vim.lsp.buf.definition, { desc = "Go to Definition", buffer = bufnr })
	vim.keymap.set('n', '<space>ri', vim.lsp.buf.implementation, { desc = "Go to Implementation", buffer = bufnr })
	vim.keymap.set('n', '<space>rr', vim.lsp.buf.references, { desc = "Go to References", buffer = bufnr })
	vim.keymap.set('n', '<space>rt', vim.lsp.buf.type_definition, { desc = "Type Definition", buffer = bufnr })
	vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, { desc = "Rename", buffer = bufnr })
	vim.keymap.set('n', '<space>ra', vim.lsp.buf.code_action, { desc = "Code Action", buffer = bufnr })
	vim.keymap.set('n', '<space>rh', vim.lsp.buf.hover, { desc = "Hover", buffer = bufnr })
	vim.keymap.set('n', '<space>rf', vim.lsp.buf.format, { desc ="Format", buffer = bufnr } )
end

local servers = {
	-- 'clangd',
  'ccls',
	'pyright',
	'bashls',
	'jsonls',
	'cmake',
	'rnix',
	'html',
}

local function enable_servers(names)
  vim.lsp.enable(names)
end

for _, lsp in ipairs(servers) do
  vim.lsp.config(lsp, {
    capabilities = capabilities,
    on_attach = set_buffer_maps,
  })
end

vim.lsp.config('lua_ls', {
  capabilities = capabilities,
  on_attach = set_buffer_maps,
  settings = {
    Lua = {
      diagnostics = {
        globals = {
          'vim'
        }
      }
    }
  }
})

vim.lsp.config('tsserver', {
  capabilities = capabilities,
  on_attach = set_buffer_maps,
})

enable_servers(servers)
enable_servers({ 'lua_ls', 'tsserver' })


local cmp = require 'cmp'
cmp.setup {
	mapping = cmp.mapping.preset.insert({
		['<C-d>'] = cmp.mapping.scroll_docs(-4),
		['<C-f>'] = cmp.mapping.scroll_docs(4),
		['<C-Space>'] = cmp.mapping.complete(),
		['<CR>'] = cmp.mapping.confirm {
			behavior = cmp.ConfirmBehavior.Replace,
			select = true,
		},
		['<Tab>'] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_next_item()
			else
				fallback()
			end
		end, { 'i', 's' }),
		['<S-Tab>'] = cmp.mapping(function(fallback)
			if cmp.visible() then
				cmp.select_prev_item()
			else
				fallback()
			end
		end, { 'i', 's' }),
	}),
	sources = {
		{ name = 'nvim_lsp' },
	},
}

require('toggle_lsp_diagnostics').init()

-- Define a variable to track if the LSP should be loaded
local lsp_enabled = true

-- Function to toggle loading of LSP
local function toggle_lsp()
  local servers = {
      --'clangd',
      'ccls',
      'pyright',
      'lua_ls',
      'bashls',
      'tsserver',
      'jsonls',
      'cmake',
      'rnix',
      'html',
      'gopls'
    }
    lsp_enabled = not lsp_enabled
    if lsp_enabled then
        enable_servers(servers)
    else
      vim.lsp.enable(servers, false)
    end
end

map("n", "<Leader>lo", toggle_lsp, { silent = false })

require'nvim-treesitter.configs'.setup {
  -- A list of parser names, or "all" (the listed parsers MUST always be installed)
  ensure_installed = { "c", "lua", "vim", "vimdoc", "query", "markdown", "markdown_inline", "regex", "cpp", "cmake", "python", "typescript", "javascript" },

  -- Install parsers synchronously (only applied to `ensure_installed`)
  sync_install = false,

  -- Automatically install missing parsers when entering buffer
  -- Recommendation: set to false if you don't have `tree-sitter` CLI installed locally
  auto_install = true,

  ---- If you need to change the installation directory of the parsers (see -> Advanced Setup)
  -- parser_install_dir = "/some/path/to/store/parsers", -- Remember to run vim.opt.runtimepath:append("/some/path/to/store/parsers")!

  highlight = {
    enable = true,

    -- NOTE: these are the names of the parsers and not the filetype. (for example if you want to
    -- disable highlighting for the `tex` filetype, you need to include `latex` in this list as this is
    -- the name of the parser)
    -- list of language that will be disabled
    -- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
    disable = function(lang, buf)
        local max_filesize = 100 * 1024 -- 100 KB
        local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
        if ok and stats and stats.size > max_filesize then
            return true
        end
    end,

    -- Setting this to true will run `:h syntax` and tree-sitter at the same time.
    -- Set this to `true` if you depend on 'syntax' being enabled (like for indentation).
    -- Using this option may slow down your editor, and you may see some duplicate highlights.
    -- Instead of true it can also be a list of languages
    additional_vim_regex_highlighting = false,
  },
}
