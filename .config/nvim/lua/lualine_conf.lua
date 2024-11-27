local function get_git_toplevel_basename()
  -- Get the directory of the current file
  local current_file = vim.fn.expand('%:p:h')

  if vim.startswith(current_file, "fugitive:///") then
    return "fugitive"
  end

	if vim.bo.buftype ~= "" then
    -- Special buffer like :checkhealth, :help, etc.
    return "special buffer"
  end

  if current_file == "" or vim.fn.isdirectory(current_file) == 0 then
    return "no file"
  end

  -- Change to the directory of the current file
  local cmd = "cd " .. current_file .. " && git rev-parse --show-toplevel 2>/dev/null"
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()

  -- Check if result is empty, indicating an error (not a git repo)
  if result == "" then
    return "no git repo"
  end

  -- Get the basename of the top-level directory
  local basename_handle = io.popen("basename " .. result)
  local basename_result = basename_handle:read("*a")
  basename_handle:close()

  return basename_result:match("^%s*(.-)%s*$") -- trim any whitespace
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
    lualine_b = { 
                  { 'hostname', 
                    icon = { '' }
                  }, 
                  { 
                    get_git_toplevel_basename, 
                    icon = { '' }
                  }, 
                  { 
                    'branch'
                  },
                  {
                    'filename', 
                    icon = { '' },
                    path = 1
                  },
                },
    lualine_c = { },
    lualine_x = { 'searchcount' },
    lualine_y = { },
    lualine_z = { }
  },
  inactive_sections = {
    lualine_a = {},
    lualine_b = { 'hostname', get_git_toplevel_basename, 'branch', {'filename', path = 1} },
    lualine_c = { },
    lualine_x = { },
    lualine_y = {},
    lualine_z = {}
  },
  tabline = {},
  winbar = {},
  inactive_winbar = {},
  extensions = {'nvim-tree', 'fzf', 'lazy', 'quickfix', 'fugitive'}
}

