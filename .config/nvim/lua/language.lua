require('map')

-- Add additional capabilities supported by nvim-cmp
local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

-- Mason handles installation of the language servers for nvim-lsp
local lspconfig = require('lspconfig')
require("mason").setup()
require("mason-lspconfig").setup({
	automatic_installation = true
})

local set_buffer_maps = function(client, bufnr)
  local bufopts = { noremap = true, silent = true, buffer = bufnr }
	vim.api.nvim_buf_set_option(bufnr, 'omnifunc', 'v:lua.vim.lsp.omnifunc')
	vim.keymap.set('n', 'gd', vim.lsp.buf.definition, bufopts)
	vim.keymap.set('n', 'K', vim.lsp.buf.hover, bufopts)
	vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, bufopts)
	vim.keymap.set('n', 'gr', vim.lsp.buf.references, bufopts)
	vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, bufopts)
	vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, bufopts)
	vim.keymap.set('n', '<space>ca', vim.lsp.buf.code_action, bufopts)
	vim.keymap.set('n', '<space>f', function() vim.lsp.buf.format { async = true } end, bufopts)
end

-- local servers = {
-- 	'clangd',
-- 	'pyright',
-- 	'lua_ls',
-- 	'bashls',
-- 	'tsserver',
-- 	'jsonls',
-- 	'cmake',
-- 	'rnix',
-- 	'html',
-- }

-- for _, lsp in ipairs(servers) do
-- 	lspconfig[lsp].setup {
-- 		capabilities = capabilities,
-- 		on_attach = set_buffer_maps
-- 	}
-- end

-- lspconfig.lua_ls.setup {
-- 	capabilities = capabilities,
-- 	on_attach = set_buffer_maps,
-- 	settings = {
-- 		Lua = {
-- 			diagnostics = {
-- 				globals = {
-- 					'vim'
-- 				}
-- 			}
-- 		}
-- 	}
-- }


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
LoadLSP = true

-- Function to toggle loading of LSP
function ToggleLSP()
  local servers = {
      'clangd',
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
    LoadLSP = not LoadLSP
    if LoadLSP then
        for _, lsp in ipairs(servers) do
            lspconfig[lsp].setup {
                capabilities = capabilities,
                on_attach = set_buffer_maps
            }
        end
        lspconfig.lua_ls.setup {
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
        }
    else
      LspStop()
    end
end

Map(
  "n",
  "<Leader>lo",
  ":lua ToggleLSP()<CR>",
  { silent = false }
)

