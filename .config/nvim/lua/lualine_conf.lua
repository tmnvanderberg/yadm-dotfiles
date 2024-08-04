local function get_git_toplevel_basename()
  local handle = io.popen("basename `git rev-parse --show-toplevel`")
  local result = handle:read("*a")
  handle:close()
  -- return result
  return result:match("^%s*(.-)%s*$") -- trim any whitespace
end

require('lualine').setup {
  options = {
    icons_enabled = true,
    theme = 'gruvbox',
    component_separators = { left = '', right = ''},
    section_separators = { left = '', right = ''},
    disabled_filetypes = {
      statusline = {},
      winbar = {},
    },
    always_divide_middle = true,
    globalstatus = false,
    refresh = {
      statusline = 1000,
      tabline = 1000,
      winbar = 1000,
    }
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'hostname', get_git_toplevel_basename, 'branch', 'diagnostics' },
    lualine_c = { {'filename', path = 3} },
    -- lualine_x = {'encoding', 'fileformat', 'filetype'},
    lualine_x = { 'searchcount', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = {},
    lualine_c = { 'filename' },
    lualine_x = { 'location' },
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {'nvim-tree', 'fzf', 'lazy', 'quickfix', 'fugitive'}
}

