local actions = require "fzf-lua.actions"
local fzf = require('fzf-lua')

local file_open_actions = {
  ['default'] = actions.file_edit,
  ['ctrl-s'] = actions.file_split,
  ['ctrl-v'] = actions.file_vsplit,
  ['ctrl-t'] = actions.file_tabedit,
}

local function read_lines(cmd, on_line)
  local handle = io.popen(cmd)
  if not handle then
    return
  end
  for line in handle:lines() do
    on_line(line)
  end
  handle:close()
end

-- browse source dirs symlinked in /src/
local function browse_source_dirs()
  local find_cmd = [[
    find -L /src/1 /src/2 /src/3 -type d -maxdepth 2 -print 2>/dev/null
  ]]

  fzf.files({
    cmd = find_cmd,
    prompt = 'Select Project Directory: ',
    previewer = 'builtin',
    cwd = '/',
  })
end

-- browse nvim configuration files
local function browse_nvim_conf()
  local base_dir = vim.fn.expand('~/.config/nvim')
  local cmd = "find " .. vim.fn.shellescape(base_dir) .. " -maxdepth 3 -type f -print 2>/dev/null"

  fzf.fzf_exec(cmd, {
    prompt = 'Select NVIM config file: ',
    previewer = 'builtin',
    actions = file_open_actions,
  })
end

local function get_current_file_dir()
  local file_path = vim.fn.expand('%:p')
  local file_dir = vim.fn.fnamemodify(file_path, ':h')
  return file_dir
end

local function browse_current_file_dir()
  local current_file_dir = get_current_file_dir()

  fzf.files({
    prompt = 'Select file (' .. current_file_dir .. ': ',
    previewer = 'builtin',
    cwd = current_file_dir,
  })
end

local function grep_current_file_dir()
  local current_file_dir = get_current_file_dir()

  fzf.grep({
    prompt = 'Grep (' .. current_file_dir .. ')> ',
    cwd = current_file_dir,
  })
end

local function browse_streamsdk_modules()
  -- Get the current working directory and append the desired subdirectory
  local base_dir = vim.fn.getcwd() .. '/src/modules'

  -- Use find to list only directories at the first level and awk to extract directory names
  local cmd = 'find ' .. vim.fn.shellescape(base_dir) .. ' -mindepth 1 -maxdepth 1 -type d -exec basename {} \\;'

  -- Create a mapping from directory names to their full paths
  local dir_map = {}
  read_lines(cmd, function(dir)
    dir_map[dir] = base_dir .. '/' .. dir
  end)

  -- Use fzf to list only directories
  fzf.fzf_exec(cmd, {
    prompt = 'Select Directory: ',
    previewer = 'builtin',
    actions = {
      ['default'] = function(selected)
        local selected_dir = dir_map[selected[1]]
          fzf.files({
            prompt = 'Select Directory: ',
            previewer = 'builtin',
            cwd = selected_dir,
          })
      end
    },
  })
end

local function grep_in_directory(dir)
  -- If no directory is provided, use the current working directory
  local base_dir = dir or vim.fn.getcwd()

  -- Use find to list only directories at the first level and extract directory names
  local cmd = 'find ' .. vim.fn.shellescape(base_dir) .. ' -type d'

  -- Create a mapping from directory names to their full paths
  local dir_map = {}
  read_lines(cmd, function(directory)
    dir_map[directory] = directory
  end)

  -- Define actions to reuse
  local action_map = {
    ['o'] = function(selected)
      local selected_dir = dir_map[selected[1]]
      -- Recursively call grep_in_directory with the selected directory
      grep_in_directory(selected_dir)
    end,
    ['default'] = function(selected)
      local selected_dir = dir_map[selected[1]]
      fzf.grep({
        prompt = 'Grep in Directory: ',
        search = '',
        cwd = selected_dir,
      })
    end,
  }

  -- Use fzf to list only directories
  fzf.fzf_exec(cmd, {
    prompt = 'Select Directory: ',
    previewer = 'builtin',
    actions = action_map,
  })
end

-- show commits for the current file directory
local function dir_commits()
  -- Get the directory of the current file
  local current_file_dir = vim.fn.expand('%:p:h')

  -- Custom git log command for the current directory
  local git_log_cmd = "git log --pretty=format:'%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset' -- " .. current_file_dir

  fzf.git_commits({
    prompt = "Git Log (" .. current_file_dir .. ")> ",
    cmd = git_log_cmd,
  })
end

local function get_vimwiki_root()
  local wiki_path = nil
  local wiki_list = vim.g.vimwiki_list
  if type(wiki_list) == "table" and type(wiki_list[1]) == "table" then
    wiki_path = wiki_list[1].path
  end

  if type(wiki_path) ~= "string" or wiki_path == "" then
    wiki_path = "~/vimwiki"
  end

  return vim.fn.expand(wiki_path)
end

local function browse_vimwiki_files(opts)
  opts = opts or {}
  local wiki_root = get_vimwiki_root()
  if vim.fn.isdirectory(wiki_root) ~= 1 then
    vim.notify("Vimwiki directory not found: " .. wiki_root, vim.log.levels.WARN)
    return
  end

  fzf.files({
    cwd = wiki_root,
    prompt = "Vimwiki Files> ",
    query = opts.query,
    previewer = "builtin",
  })
end

local function grep_vimwiki(opts)
  opts = opts or {}
  local wiki_root = get_vimwiki_root()
  if vim.fn.isdirectory(wiki_root) ~= 1 then
    vim.notify("Vimwiki directory not found: " .. wiki_root, vim.log.levels.WARN)
    return
  end

  fzf.grep({
    cwd = wiki_root,
    prompt = "Vimwiki Grep> ",
    search = opts.search or "",
  })
end

local function insert_text_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  vim.api.nvim_buf_set_text(0, row, col, row, col, { text })
  vim.api.nvim_win_set_cursor(0, { row + 1, col + #text })
end

local function insert_block_at_cursor(text)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  row = row - 1
  local lines = vim.split(text or "", "\n", { plain = true })
  if #lines == 0 then
    lines = { "" }
  end
  vim.api.nvim_buf_set_text(0, row, col, row, col, lines)

  local last_line = lines[#lines] or ""
  local new_row = row + #lines
  local new_col = (#lines == 1) and (col + #last_line) or #last_line
  vim.api.nvim_win_set_cursor(0, { new_row, new_col })
end

local function run_cmd_async(argv, on_done)
  local stdout = {}
  local stderr = {}

  local function append_lines(target, data)
    if type(data) ~= "table" then
      return
    end
    for _, line in ipairs(data) do
      if line and line ~= "" then
        table.insert(target, line)
      end
    end
  end

  local job_id = vim.fn.jobstart(argv, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      append_lines(stdout, data)
    end,
    on_stderr = function(_, data)
      append_lines(stderr, data)
    end,
    on_exit = function(_, code)
      local out = table.concat(stdout, "\n")
      local err = table.concat(stderr, "\n")
      if err ~= "" then
        out = (out ~= "" and (out .. "\n") or "") .. err
      end
      vim.schedule(function()
        on_done(out, code)
      end)
    end,
  })

  if job_id <= 0 then
    vim.schedule(function()
      on_done("Failed to start command: " .. table.concat(argv, " "), 1)
    end)
  end
end

local spinner = {
  timer = nil,
  frames = { "|", "/", "-", "\\" },
  idx = 1,
  msg = "",
}

local function spinner_render()
  if not spinner.timer then
    return
  end
  local frame = spinner.frames[spinner.idx]
  spinner.idx = (spinner.idx % #spinner.frames) + 1
  vim.api.nvim_echo({ { string.format("%s %s", frame, spinner.msg), "ModeMsg" } }, false, {})
  vim.cmd("redraw")
end

local function spinner_start(msg)
  if spinner.timer then
    spinner.timer:stop()
    spinner.timer:close()
    spinner.timer = nil
  end
  spinner.idx = 1
  spinner.msg = msg or "Working..."
  spinner.timer = vim.loop.new_timer()
  spinner.timer:start(0, 100, vim.schedule_wrap(spinner_render))
end

local function spinner_stop(final_msg, level)
  if spinner.timer then
    spinner.timer:stop()
    spinner.timer:close()
    spinner.timer = nil
  end
  if final_msg and final_msg ~= "" then
    vim.notify(final_msg, level or vim.log.levels.INFO)
  else
    vim.api.nvim_echo({ { "", "None" } }, false, {})
    vim.cmd("redraw")
  end
end

local function extract_workitems(decoded)
  if type(decoded) ~= "table" then
    return {}
  end

  if vim.tbl_islist(decoded) then
    return decoded
  end

  for _, key in ipairs({ "workItems", "issues", "results", "items", "values", "data" }) do
    if vim.tbl_islist(decoded[key]) then
      return decoded[key]
    end
  end

  return {}
end

local function extract_key_summary(item)
  if type(item) ~= "table" then
    return nil, nil
  end

  local key = item.key or item.id or item.issueKey
  local summary = item.summary

  if type(item.fields) == "table" then
    summary = summary or item.fields.summary
    key = key or item.fields.key
  end

  if type(summary) == "table" then
    summary = summary.value or summary.text
  end

  if type(key) ~= "string" or key == "" then
    return nil, nil
  end
  if type(summary) ~= "string" or summary == "" then
    summary = "(no summary)"
  end

  return key, summary
end

local function clean_jira_text(text)
  text = tostring(text or "")
  -- Remove ANSI escapes and non-printable controls that can confuse fzf rendering.
  text = text:gsub("\27%[[0-9;]*[A-Za-z]", "")
  text = text:gsub("[%z\1-\8\11\12\14-\31\127]", "")
  text = text:gsub("[\r\n\t]", " ")
  text = vim.trim(text)
  return text
end

local function decode_json(output)
  local ok, decoded = pcall(vim.json.decode, output)
  if ok then
    return decoded
  end
  return nil
end

local function decode_json_pages(output)
  if type(output) ~= "string" or output == "" then
    return nil
  end

  local chunks = {}
  local depth = 0
  local in_string = false
  local escaped = false
  local start_idx = nil

  for i = 1, #output do
    local ch = output:sub(i, i)
    if in_string then
      if escaped then
        escaped = false
      elseif ch == "\\" then
        escaped = true
      elseif ch == '"' then
        in_string = false
      end
    else
      if ch == '"' then
        in_string = true
      elseif ch == "{" then
        if depth == 0 then
          start_idx = i
        end
        depth = depth + 1
      elseif ch == "}" then
        if depth > 0 then
          depth = depth - 1
          if depth == 0 and start_idx then
            table.insert(chunks, output:sub(start_idx, i))
            start_idx = nil
          end
        end
      end
    end
  end

  if #chunks == 0 then
    return nil
  end

  local pages = {}
  for _, chunk in ipairs(chunks) do
    local decoded = decode_json(chunk)
    if decoded then
      table.insert(pages, decoded)
    end
  end

  if #pages == 0 then
    return nil
  end

  return pages
end

local function encode_json(value)
  local ok, encoded = pcall(vim.json.encode, value)
  if ok then
    return encoded
  end
  local ok2, encoded2 = pcall(vim.fn.json_encode, value)
  if ok2 then
    return encoded2
  end
  return "<json encode failed>"
end

local function jira_debug_log(stage, argv, output)
  local cmd = type(argv) == "table" and table.concat(argv, " ") or tostring(argv or "")
  local body = tostring(output or "")
  local path = vim.fn.tempname() .. "_jira_debug.log"

  local content = table.concat({
    "stage: " .. tostring(stage or "unknown"),
    "time: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "command: " .. cmd,
    "",
    body,
    "",
  }, "\n")

  local ok = pcall(vim.fn.writefile, vim.split(content, "\n", { plain = true }), path)
  if ok then
    vim.notify("Jira debug log written: " .. path, vim.log.levels.WARN)
  else
    vim.notify("Jira debug logging failed for stage: " .. tostring(stage), vim.log.levels.WARN)
  end
end

local function build_jira_view_fields()
  local fields = {
    "key",
    "summary",
    "status",
    "assignee",
    "description",
    "comment",
    "duedate",
    "Story Points",
    "Definition of Done (D.o.D)",
  }

  local configured_key = vim.g.jira_definition_of_done_field
  if type(configured_key) == "string" and configured_key ~= "" then
    table.insert(fields, configured_key)
  end

  return table.concat(fields, ",")
end

local function normalize_field_name(name)
  local normalized = tostring(name or ""):lower()
  normalized = normalized:gsub("[^%w]", "")
  return normalized
end

local function extract_workitem_object(decoded)
  if type(decoded) ~= "table" then
    return nil
  end
  if decoded.key or decoded.summary or decoded.fields then
    return decoded
  end
  for _, k in ipairs({ "workItem", "issue", "item", "data", "result" }) do
    if type(decoded[k]) == "table" then
      return decoded[k]
    end
  end
  return decoded
end

local function adf_to_text(node)
  if type(node) == "string" then
    return node
  end
  if type(node) ~= "table" then
    return nil
  end

  if node.type == "text" and type(node.text) == "string" then
    return node.text
  end

  local content = node.content
  if type(content) ~= "table" then
    return nil
  end

  local parts = {}
  for _, child in ipairs(content) do
    local chunk = adf_to_text(child)
    if chunk and chunk ~= "" then
      table.insert(parts, chunk)
    end
    if type(child) == "table" then
      if child.type == "hardBreak" or child.type == "paragraph" then
        table.insert(parts, "\n")
      end
      if child.type == "listItem" then
        table.insert(parts, "\n")
      end
    end
  end

  local text = table.concat(parts)
  text = text:gsub("\n\n\n+", "\n\n")
  text = vim.trim(text)
  if text == "" then
    return nil
  end
  return text
end

local function value_to_text(value)
  if value == nil then
    return nil
  end
  if type(value) == "string" then
    local s = vim.trim(value)
    return s ~= "" and s or nil
  end
  if type(value) == "number" or type(value) == "boolean" then
    return tostring(value)
  end
  if type(value) ~= "table" then
    return nil
  end

  local adf_text = adf_to_text(value)
  if adf_text and adf_text ~= "" then
    return adf_text
  end

  for _, key in ipairs({ "displayName", "name", "value", "text", "emailAddress", "key" }) do
    local v = value[key]
    if type(v) == "string" and vim.trim(v) ~= "" then
      return vim.trim(v)
    end
  end

  if vim.tbl_islist(value) then
    local parts = {}
    for _, item in ipairs(value) do
      local t = value_to_text(item)
      if t and t ~= "" then
        table.insert(parts, t)
      end
    end
    if #parts > 0 then
      return table.concat(parts, "\n")
    end
    return nil
  end

  return nil
end

local function find_field_value(obj, wanted, contains_match)
  if type(obj) ~= "table" then
    return nil
  end
  local wanted_norm = {}
  for _, name in ipairs(wanted) do
    table.insert(wanted_norm, normalize_field_name(name))
  end

  local function matches(key_norm)
    for _, w in ipairs(wanted_norm) do
      if key_norm == w then
        return true
      end
      if contains_match and key_norm:find(w, 1, true) then
        return true
      end
    end
    return false
  end

  local function scan(tbl)
    for k, v in pairs(tbl) do
      if type(k) == "string" and matches(normalize_field_name(k)) then
        return v
      end
    end
    for _, v in pairs(tbl) do
      if type(v) == "table" and not vim.tbl_islist(v) then
        local found = scan(v)
        if found ~= nil then
          return found
        end
      end
    end
    return nil
  end

  return scan(obj)
end

local function extract_definition_of_done(item)
  item = extract_workitem_object(item) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  -- 1) Optional explicit override: let user pin their custom field key.
  local configured_key = vim.g.jira_definition_of_done_field
  if type(configured_key) == "string" and configured_key ~= "" then
    local v = fields[configured_key]
    local t = value_to_text(v)
    if t and t ~= "" then
      return t
    end
  end

  -- 2) Direct key/name matching in payload.
  local direct = find_field_value(item, {
    "Definition of Done (D.o.D)",
    "Definition of Done",
    "DoD",
    "definition of done",
    "dod",
  }, true)
  local direct_text = value_to_text(direct)
  if direct_text and direct_text ~= "" then
    return direct_text
  end

  -- 3) Use Jira names map if present (customfield_x -> human name).
  local names = type(item.names) == "table" and item.names or nil
  if names then
    for field_key, display_name in pairs(names) do
      local n = normalize_field_name(display_name)
      if n:find("definitionofdone", 1, true) or n == "dod" then
        local t = value_to_text(fields[field_key])
        if t and t ~= "" then
          return t
        end
      end
    end
  end

  -- 4) Heuristic over field keys (helps when key already contains readable text).
  for field_key, value in pairs(fields) do
    local k = normalize_field_name(field_key)
    if k:find("definitionofdone", 1, true) or k == "dod" then
      local t = value_to_text(value)
      if t and t ~= "" then
        return t
      end
    end
  end

  return nil
end

local function markdown_from_workitem(decoded, fallback_key)
  local item = extract_workitem_object(decoded) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  local key = value_to_text(item.key) or value_to_text(fields.key) or fallback_key or "(unknown key)"
  local summary = value_to_text(item.summary) or value_to_text(fields.summary) or "(no summary)"

  local status_val = fields.status or find_field_value(item, { "status" }, false)
  local assignee_val = fields.assignee or find_field_value(item, { "assignee" }, false)
  local due_val = fields.duedate or find_field_value(item, { "due date", "duedate" }, true)
  local sp_val = find_field_value(item, { "story points", "storypoints" }, true)
  local dod_val = extract_definition_of_done(item)
  local desc_val = fields.description or find_field_value(item, { "description" }, false)
  local comment_val = fields.comment or find_field_value(item, { "comment" }, true)

  local status = value_to_text(status_val) or "-"
  local assignee = value_to_text(assignee_val) or "-"
  local due = value_to_text(due_val) or "-"
  local story_points = value_to_text(sp_val) or "-"
  local dod = value_to_text(dod_val) or "-"
  local description = value_to_text(desc_val) or "-"

  local lines = {
    string.format("## %s: %s", key, summary),
    "",
    string.format("- **Status:** %s", status),
    string.format("- **Assignee:** %s", assignee),
    string.format("- **Story Points:** %s", story_points),
    string.format("- **Due Date:** %s", due),
    "",
    "### Definition of Done (D.o.D)",
    dod,
    "",
    "### Description",
    description,
  }

  local comments = nil
  if type(comment_val) == "table" then
    comments = comment_val.comments or comment_val.values or (vim.tbl_islist(comment_val) and comment_val or nil)
  elseif type(comment_val) == "string" then
    comments = { { body = comment_val } }
  end

  table.insert(lines, "")
  table.insert(lines, "### Comments")
  if type(comments) == "table" and #comments > 0 then
    for _, c in ipairs(comments) do
      local author = value_to_text(c.author) or value_to_text(c.updateAuthor) or "Unknown"
      local created = value_to_text(c.created) or value_to_text(c.updated) or ""
      local body = value_to_text(c.body) or "-"
      local header = (created ~= "") and string.format("- **%s** (%s)", author, created) or string.format("- **%s**", author)
      table.insert(lines, header)
      table.insert(lines, "  " .. body:gsub("\n", "\n  "))
    end
  else
    table.insert(lines, "- (no comments)")
  end

  return table.concat(lines, "\n")
end

local function view_jira_workitem(key)
  spinner_start("Jira: loading " .. key .. " ...")
  local jira_view_fields = build_jira_view_fields()
  run_cmd_async(
    { "acli", "jira", "workitem", "view", key, "--fields", jira_view_fields, "--json" },
    function(output, code)
      spinner_stop()
      if code ~= 0 then
        vim.notify("Failed to fetch Jira work item " .. key .. ":\n" .. output, vim.log.levels.ERROR)
        return
      end
      local decoded = decode_json(output)
      if not decoded then
        vim.notify("Could not parse Jira ticket JSON. Inserting raw output.", vim.log.levels.WARN)
        insert_block_at_cursor(output)
        return
      end

      -- If DoD is still unresolved, retry once with *all fields.
      local initial_dod = extract_definition_of_done(decoded)
      if not initial_dod or initial_dod == "" then
        spinner_start("Jira: loading all fields for DoD ...")
        run_cmd_async(
          { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
          function(all_output, all_code)
            spinner_stop()
            if all_code == 0 then
              local all_decoded = decode_json(all_output)
              if all_decoded then
                insert_block_at_cursor(markdown_from_workitem(all_decoded, key))
                return
              end
            end
            insert_block_at_cursor(markdown_from_workitem(decoded, key))
          end
        )
        return
      end

      insert_block_at_cursor(markdown_from_workitem(decoded, key))
    end
  )
end

local function find_ticket_key_in_text(text)
  if type(text) ~= "string" then
    return nil
  end
  local upper = text:upper()
  return upper:match("([A-Z][A-Z0-9_]+%-%d+)")
end

local function resolve_ticket_key(opts, on_resolved)
  opts = opts or {}
  local detected_key = find_ticket_key_in_text(opts.key)
    or find_ticket_key_in_text(opts.args)
    or find_ticket_key_in_text(opts.query)
    or find_ticket_key_in_text(vim.fn.expand("<cword>"))
    or find_ticket_key_in_text(vim.fn.expand("<cWORD>"))
    or nil

  if detected_key and detected_key ~= "" then
    on_resolved(detected_key)
    return
  end

  vim.ui.input({ prompt = "Ticket Key (e.g. DOPS-123)> " }, function(input)
    local key = find_ticket_key_in_text(input)
    if key and key ~= "" then
      on_resolved(key)
      return
    end
    vim.notify("No valid Jira ticket key provided", vim.log.levels.WARN)
  end)
end

local function open_markdown_preview_window(title, markdown)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(markdown, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false

  local width = math.max(80, math.floor(vim.o.columns * 0.72))
  local height = math.max(20, math.floor(vim.o.lines * 0.78))
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = math.max(0, row),
    col = math.max(0, col),
    width = math.min(width, vim.o.columns - 4),
    height = math.min(height, vim.o.lines - 4),
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "left",
  })
end

local function preview_jira_workitem(key)
  spinner_start("Jira: previewing " .. key .. " ...")
  local jira_view_fields = build_jira_view_fields()
  run_cmd_async(
    { "acli", "jira", "workitem", "view", key, "--fields", jira_view_fields, "--json" },
    function(output, code)
      spinner_stop()
      if code ~= 0 then
        vim.notify("Failed to fetch Jira work item " .. key .. ":\n" .. output, vim.log.levels.ERROR)
        return
      end
      local decoded = decode_json(output)
      if not decoded then
        vim.notify("Could not parse Jira ticket JSON output", vim.log.levels.ERROR)
        return
      end
      open_markdown_preview_window("Jira Preview: " .. key, markdown_from_workitem(decoded, key))
    end
  )
end

local function jira_preview_ticket(opts)
  resolve_ticket_key(opts, function(key)
    preview_jira_workitem(key)
  end)
end

local function open_url_in_browser(url)
  local openers = {
    { "open", url },               -- macOS
    { "xdg-open", url },           -- Linux
    { "cmd", "/c", "start", url }, -- Windows
  }

  local function try_idx(i)
    if i > #openers then
      vim.notify("Could not open browser for URL: " .. url, vim.log.levels.ERROR)
      return
    end

    run_cmd_async(openers[i], function(_, code)
      if code == 0 then
        return
      end
      try_idx(i + 1)
    end)
  end

  try_idx(1)
end

local function open_jira_workitem_link(key)
  spinner_start("Jira: opening " .. key .. " ...")
  run_cmd_async(
    { "acli", "jira", "workitem", "view", key, "--web" },
    function(output, code)
      spinner_stop()
      if code ~= 0 then
        -- Fallback if acli --web fails in this environment.
        run_cmd_async(
          { "acli", "jira", "workitem", "view", key, "--fields", "key", "--json" },
          function(json_out, json_code)
            if json_code ~= 0 then
              vim.notify("Failed to open Jira work item " .. key .. ":\n" .. output, vim.log.levels.ERROR)
              return
            end
            local decoded = decode_json(json_out)
            local item = decoded and extract_workitem_object(decoded) or nil
            local self_url = item and value_to_text(item.self) or nil
            local host = self_url and self_url:match("^(https?://[^/]+)/") or nil
            if not host then
              vim.notify("Failed to derive Jira URL for " .. key, vim.log.levels.ERROR)
              return
            end
            open_url_in_browser(host .. "/browse/" .. key)
          end
        )
      end
    end
  )
end

local function jira_open_ticket(opts)
  resolve_ticket_key(opts, function(key)
    open_jira_workitem_link(key)
  end)
end

local function open_jira_search_results(output, on_select)
  local decoded = decode_json(output)
  if not decoded then
    spinner_stop()
    vim.notify("Could not parse Jira search JSON output", vim.log.levels.ERROR)
    return
  end

  local workitems = extract_workitems(decoded)
  local entries = {}
  local key_by_entry = {}

  for _, item in ipairs(workitems) do
    local key, summary = extract_key_summary(item)
    if key then
      local clean_key = clean_jira_text(key)
      local clean_summary = clean_jira_text(summary)
      local entry = string.format("%s | %s", clean_key, clean_summary)
      table.insert(entries, entry)
      key_by_entry[entry] = clean_key
    end
  end

  spinner_stop()
  if #entries == 0 then
    vim.notify("No Jira work items found for this query", vim.log.levels.INFO)
    return
  end

  fzf.fzf_exec(entries, {
    prompt = "Jira> ",
    previewer = false,
    fzf_opts = {
      ["--ansi"] = false,
    },
    actions = {
      ['default'] = function(selected)
        local entry = selected and selected[1]
        local key = entry and key_by_entry[entry] or nil
        if not key and entry then
          key = entry:match("^%s*([^|%s]+)")
          if key then
            key = vim.trim(key)
          end
        end
        if key and key ~= "" then
          on_select(key)
        end
      end,
    },
  })
end

local function jira_search_by_jql(jql, on_select)
  spinner_start("Jira: searching ...")
  run_cmd_async(
    { "acli", "jira", "workitem", "search", "--jql", jql, "--fields", "key,summary", "--limit", "200", "--json" },
    function(output, code)
      if code ~= 0 then
        spinner_stop()
        vim.notify("Jira search failed:\n" .. output, vim.log.levels.ERROR)
        return
      end
      open_jira_search_results(output, on_select)
    end
  )
end

local function wrap_text_as_jql(text)
  local escaped = text:gsub("\\", "\\\\"):gsub('"', '\\"')
  return string.format('text ~ "%s"', escaped)
end

local function extract_projects(decoded)
  if type(decoded) ~= "table" then
    return {}
  end
  if vim.tbl_islist(decoded) then
    return decoded
  end
  for _, key in ipairs({ "projects", "values", "results", "items", "data" }) do
    if vim.tbl_islist(decoded[key]) then
      return decoded[key]
    end
  end
  return {}
end

local function extract_project_key_name(project)
  if type(project) ~= "table" then
    return nil, nil
  end
  local key = project.key or project.id
  local name = project.name or project.displayName
  if type(key) ~= "string" or key == "" then
    return nil, nil
  end
  if type(name) ~= "string" or name == "" then
    name = key
  end
  return key, name
end

local function extract_status_assignee_parent(item)
  local fields = type(item.fields) == "table" and item.fields or {}
  local status_val = fields.status or find_field_value(item, { "status" }, false)
  local assignee_val = fields.assignee or find_field_value(item, { "assignee" }, false)
  local status = value_to_text(status_val) or "-"
  local assignee = value_to_text(assignee_val) or "-"

  local parent_val = fields.parent or item.parent or find_field_value(item, { "parent" }, false)
  local parent_key = nil
  local parent_name = nil
  if type(parent_val) == "table" then
    parent_key = value_to_text(parent_val.key) or value_to_text(parent_val.issueKey)
    parent_name = value_to_text(parent_val.summary) or value_to_text(parent_val.name) or value_to_text(parent_val.title)
    if not parent_key and type(parent_val.fields) == "table" then
      parent_key = value_to_text(parent_val.fields.key)
      parent_name = parent_name
        or value_to_text(parent_val.fields.summary)
        or value_to_text(parent_val.fields.name)
        or value_to_text(parent_val.fields.title)
    end
  elseif type(parent_val) == "string" and parent_val ~= "" then
    parent_name = parent_val
    if parent_val:match("^[A-Z][A-Z0-9_]+%-%d+$") then
      parent_key = parent_val
    end
  end

  return status, assignee, parent_key, parent_name
end

local function is_done_status(status)
  local s = string.lower(tostring(status or ""))
  return s == "done" or s:find("done", 1, true) ~= nil
end

local function markdown_strike_if_done(text, status)
  if is_done_status(status) then
    return "~~" .. text .. "~~"
  end
  return text
end

local function build_epics_stories_report(project_key, project_name, epics, stories, exclude_done)
  local function normalize_match(text)
    text = clean_jira_text(text or ""):lower()
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")
    return vim.trim(text)
  end

  local lines = {}
  table.insert(lines, string.format("Project: %s [%s]", project_name, project_key))
  table.insert(lines, string.format("Scope: %s", exclude_done and "excluding Done issues" or "including Done issues"))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")
  table.insert(lines, "Epics:")

  if #epics == 0 then
    table.insert(lines, "  (none)")
    table.insert(lines, "")
  end

  local epic_by_key = {}
  local epic_key_by_summary = {}
  local epic_keys = {}
  for _, epic in ipairs(epics) do
    epic_by_key[epic.key] = epic
    local summary_norm = normalize_match(epic.summary)
    if summary_norm ~= "" and not epic_key_by_summary[summary_norm] then
      epic_key_by_summary[summary_norm] = epic.key
    end
    table.insert(epic_keys, epic.key)
  end
  table.sort(epic_keys)

  local stories_by_epic = {}
  local unparented_stories = {}
  for _, story in ipairs(stories) do
    local bucket_key = nil
    if story.parent_key and epic_by_key[story.parent_key] then
      bucket_key = story.parent_key
    elseif story.parent_name and epic_key_by_summary[normalize_match(story.parent_name)] then
      bucket_key = epic_key_by_summary[normalize_match(story.parent_name)]
    elseif story.parent_key and epic_key_by_summary[normalize_match(story.parent_key)] then
      bucket_key = epic_key_by_summary[normalize_match(story.parent_key)]
    end

    if bucket_key then
      stories_by_epic[bucket_key] = stories_by_epic[bucket_key] or {}
      table.insert(stories_by_epic[bucket_key], story)
    else
      table.insert(unparented_stories, story)
    end
  end

  for _, epic_key in ipairs(epic_keys) do
    local epic = epic_by_key[epic_key]
    local epic_label = string.format(
      "[%s] %s [status:%s] [assignee:%s]",
      epic.key,
      epic.summary,
      epic.status,
      epic.assignee
    )
    epic_label = markdown_strike_if_done(epic_label, epic.status)
    table.insert(
      lines,
      "  - " .. epic_label
    )
    local bucket = stories_by_epic[epic_key] or {}
    if #bucket == 0 then
      table.insert(lines, "      (no stories)")
    else
      table.sort(bucket, function(a, b) return a.key < b.key end)
      for _, story in ipairs(bucket) do
        local story_label = string.format(
          "[%s] %s [status:%s] [assignee:%s]",
          story.key,
          story.summary,
          story.status,
          story.assignee
        )
        story_label = markdown_strike_if_done(story_label, story.status)
        table.insert(
          lines,
          "      - " .. story_label
        )
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Unparented Stories:")
  if #unparented_stories == 0 then
    table.insert(lines, "  (none)")
  else
    table.sort(unparented_stories, function(a, b) return a.key < b.key end)
    for _, story in ipairs(unparented_stories) do
      local story_label = string.format(
        "[%s] %s [status:%s] [assignee:%s]",
        story.key,
        story.summary,
        story.status,
        story.assignee
      )
      story_label = markdown_strike_if_done(story_label, story.status)
      table.insert(
        lines,
        "  - " .. story_label
      )
    end
  end

  return table.concat(lines, "\n")
end

local function jira_project_epics_stories_report_for_project(project_key, project_name, exclude_done)
  local function jql_quote(value)
    local v = tostring(value or "")
    v = v:gsub("\\", "\\\\"):gsub('"', '\\"')
    return '"' .. v .. '"'
  end

  local function search_workitems_by_jql(jql, fields, on_done)
    run_cmd_async(
      { "acli", "jira", "workitem", "search", "--jql", jql, "--fields", fields, "--paginate", "--json" },
      function(output, code)
        if code ~= 0 then
          on_done(nil, output)
          return
        end
        local decoded = decode_json(output)
        if not decoded then
          on_done(nil, "Could not parse JSON output")
          return
        end
        on_done(extract_workitems(decoded), nil)
      end
    )
  end

  local done_filter = exclude_done and " AND statusCategory != Done" or ""

  spinner_start("Jira: loading epics ...")
  local epic_jql = string.format("project = %s AND issuetype = Epic%s ORDER BY key ASC", jql_quote(project_key), done_filter)
  search_workitems_by_jql(epic_jql, "key,summary,status,assignee", function(epic_items, epic_err)
    if not epic_items then
      spinner_stop()
      vim.notify("Failed to fetch epics:\n" .. tostring(epic_err), vim.log.levels.ERROR)
      return
    end

    local epics = {}
    for _, item in ipairs(epic_items) do
      local key, summary = extract_key_summary(item)
      if key then
        local status, assignee = extract_status_assignee_parent(item)
        table.insert(epics, {
          key = clean_jira_text(key),
          summary = clean_jira_text(summary),
          status = clean_jira_text(status),
          assignee = clean_jira_text(assignee),
        })
      end
    end

    local stories_by_key = {}
    local function upsert_story(item, forced_parent_key)
      local key, summary = extract_key_summary(item)
      if not key then
        return
      end
      local status, assignee = extract_status_assignee_parent(item)
      local clean_key = clean_jira_text(key)
      local existing = stories_by_key[clean_key]
      if not existing then
        existing = {
          key = clean_key,
          summary = clean_jira_text(summary),
          status = clean_jira_text(status),
          assignee = clean_jira_text(assignee),
          parent_key = forced_parent_key and clean_jira_text(forced_parent_key) or nil,
        }
        stories_by_key[clean_key] = existing
      elseif (not existing.parent_key or existing.parent_key == "") and forced_parent_key then
        existing.parent_key = clean_jira_text(forced_parent_key)
      end
    end

    spinner_start("Jira: linking stories to epics ...")
    local function fetch_for_epic_with_variants(epic, done)
      local variants = {
        string.format("project = %s AND issuetype = Story AND parent = %s%s ORDER BY key ASC", jql_quote(project_key), jql_quote(epic.key), done_filter),
        string.format('project = %s AND issuetype = Story AND "parent epic" = %s%s ORDER BY key ASC', jql_quote(project_key), jql_quote(epic.key), done_filter),
        string.format('project = %s AND issuetype = Story AND "Epic Link" = %s%s ORDER BY key ASC', jql_quote(project_key), jql_quote(epic.key), done_filter),
      }

      local function run_variant(i)
        if i > #variants then
          done()
          return
        end
        search_workitems_by_jql(variants[i], "key,summary,status,assignee", function(items, _)
          if items and #items > 0 then
            for _, item in ipairs(items) do
              upsert_story(item, epic.key)
            end
            -- Fast path: once a matching variant works for this epic, skip the rest.
            done()
            return
          end
          run_variant(i + 1)
        end)
      end

      run_variant(1)
    end

    local function finalize_after_epic_linking()
        spinner_start("Jira: loading remaining stories ...")
        local all_story_jql = string.format("project = %s AND issuetype = Story%s ORDER BY key ASC", jql_quote(project_key), done_filter)
        search_workitems_by_jql(all_story_jql, "key,summary,status,assignee", function(all_story_items, all_story_err)
          if not all_story_items then
            spinner_stop()
            vim.notify("Failed to fetch stories:\n" .. tostring(all_story_err), vim.log.levels.ERROR)
            return
          end

          for _, item in ipairs(all_story_items) do
            upsert_story(item, nil)
          end

          local stories = {}
          for _, story in pairs(stories_by_key) do
            table.insert(stories, story)
          end
          table.sort(stories, function(a, b) return a.key < b.key end)

          spinner_stop()
          insert_block_at_cursor(build_epics_stories_report(project_key, project_name, epics, stories, exclude_done))
        end)
    end

    if #epics == 0 then
      finalize_after_epic_linking()
      return
    end

    -- Process epics concurrently with a small cap to reduce total wall time.
    local max_concurrency = 6
    local next_idx = 1
    local active = 0

    local function pump()
      while active < max_concurrency and next_idx <= #epics do
        local epic = epics[next_idx]
        next_idx = next_idx + 1
        active = active + 1
        fetch_for_epic_with_variants(epic, function()
          active = active - 1
          if next_idx > #epics and active == 0 then
            finalize_after_epic_linking()
            return
          end
          pump()
        end)
      end
    end

    pump()
  end)
end

local function jira_project_epics_stories(opts)
  opts = opts or {}
  local raw_opts = string.lower(vim.trim(opts.args or opts.query or ""))
  local exclude_done = opts.exclude_done ~= false
  if raw_opts ~= "" then
    if raw_opts:find("%-%-include%-done", 1, true) then
      exclude_done = false
    elseif raw_opts:find("%-%-exclude%-done", 1, true) or raw_opts == "exclude_done" or raw_opts == "exclude-done" then
      exclude_done = true
    end
  end

  spinner_start("Jira: loading projects ...")
  run_cmd_async({ "acli", "jira", "project", "list", "--paginate", "--json" }, function(output, code)
    if code ~= 0 then
      spinner_stop()
      vim.notify("Failed to load Jira projects:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      spinner_stop()
      vim.notify("Could not parse project list JSON output", vim.log.levels.ERROR)
      return
    end

    local entries = {}
    local project_by_entry = {}
    for _, project in ipairs(extract_projects(decoded)) do
      local key, name = extract_project_key_name(project)
      if key then
        local entry = string.format("%s | %s", clean_jira_text(key), clean_jira_text(name))
        table.insert(entries, entry)
        project_by_entry[entry] = { key = key, name = name }
      end
    end

    spinner_stop()
    if #entries == 0 then
      vim.notify("No Jira projects found", vim.log.levels.INFO)
      return
    end

    table.sort(entries)
    fzf.fzf_exec(entries, {
      prompt = "Jira Project> ",
      previewer = false,
      fzf_opts = {
        ["--ansi"] = false,
      },
      actions = {
        ['default'] = function(selected)
          local entry = selected and selected[1]
          local project = entry and project_by_entry[entry] or nil
          if not project and entry then
            local key = entry:match("^%s*([^|%s]+)")
            if key then
              key = vim.trim(key)
              project = { key = key, name = key }
            end
          end
          if project and project.key and project.key ~= "" then
            jira_project_epics_stories_report_for_project(project.key, project.name or project.key, exclude_done)
          end
        end,
      },
    })
  end)
end

local function extract_list(decoded, keys)
  if type(decoded) ~= "table" then
    return {}
  end
  if vim.tbl_islist(decoded) then
    return decoded
  end
  for _, key in ipairs(keys) do
    if vim.tbl_islist(decoded[key]) then
      return decoded[key]
    end
  end
  return {}
end

local function extract_boards(decoded)
  return extract_list(decoded, { "boards", "values", "results", "items", "data" })
end

local function extract_sprints(decoded)
  return extract_list(decoded, { "sprints", "values", "results", "items", "data" })
end

local function extract_board_id_name(board)
  if type(board) ~= "table" then
    return nil, nil
  end
  local id = board.id
  local name = board.name
  if (type(id) ~= "number" and type(id) ~= "string") then
    return nil, nil
  end
  if type(name) ~= "string" or name == "" then
    name = tostring(id)
  end
  return tonumber(id) or id, name
end

local function extract_sprint_info(sprint)
  if type(sprint) ~= "table" then
    return nil
  end
  local id = sprint.id
  if type(id) ~= "number" and type(id) ~= "string" then
    return nil
  end
  local name = value_to_text(sprint.name) or tostring(id)
  local state = value_to_text(sprint.state) or "-"
  local sprint_number = nil
  local from_name = tostring(name):match("[Ss]print%s*(%d+)")
  if from_name then
    sprint_number = tonumber(from_name)
  elseif type(id) == "number" then
    sprint_number = id
  elseif type(id) == "string" then
    sprint_number = tonumber(id)
  end
  return {
    id = tonumber(id) or id,
    name = clean_jira_text(name),
    state = clean_jira_text(state),
    sprint_number = sprint_number,
    start_date = value_to_text(sprint.startDate),
    end_date = value_to_text(sprint.endDate),
    complete_date = value_to_text(sprint.completeDate),
    issues = {},
  }
end

local function build_project_sprints_report(project_key, project_name, board_name, sprints)
  local function norm_date(s)
    s = tostring(s or "")
    if s == "" then
      return nil
    end
    -- ISO-8601 date/time strings sort lexicographically.
    return s
  end

  local function cmp_date(a, b, asc)
    local da = norm_date(a)
    local db = norm_date(b)
    if da and db and da ~= db then
      if asc then
        return da < db
      end
      return da > db
    end
    if da and not db then
      return true
    end
    if db and not da then
      return false
    end
    return nil
  end

  local function cmp_newer_first(a, b)
    if a.sprint_number and b.sprint_number and a.sprint_number ~= b.sprint_number then
      return a.sprint_number > b.sprint_number
    end
    local by_complete = cmp_date(a.complete_date, b.complete_date, false)
    if by_complete ~= nil then
      return by_complete
    end
    local by_end = cmp_date(a.end_date, b.end_date, false)
    if by_end ~= nil then
      return by_end
    end
    local by_start = cmp_date(a.start_date, b.start_date, false)
    if by_start ~= nil then
      return by_start
    end
    local aid = tonumber(a.id)
    local bid = tonumber(b.id)
    if aid and bid and aid ~= bid then
      return aid > bid
    end
    return a.name > b.name
  end

  local function cmp_older_first(a, b)
    if a.sprint_number and b.sprint_number and a.sprint_number ~= b.sprint_number then
      return a.sprint_number < b.sprint_number
    end
    local by_start = cmp_date(a.start_date, b.start_date, true)
    if by_start ~= nil then
      return by_start
    end
    local by_end = cmp_date(a.end_date, b.end_date, true)
    if by_end ~= nil then
      return by_end
    end
    local by_complete = cmp_date(a.complete_date, b.complete_date, true)
    if by_complete ~= nil then
      return by_complete
    end
    local aid = tonumber(a.id)
    local bid = tonumber(b.id)
    if aid and bid and aid ~= bid then
      return aid < bid
    end
    return a.name < b.name
  end

  local closed = {}
  local active = {}
  local future = {}
  for _, s in ipairs(sprints) do
    local st = string.lower(s.state or "")
    if st == "closed" then
      table.insert(closed, s)
    elseif st == "active" then
      table.insert(active, s)
    elseif st == "future" then
      table.insert(future, s)
    else
      table.insert(future, s)
    end
  end

  -- Keep only the most recent 5 closed sprints, then display old->new.
  table.sort(closed, cmp_newer_first)
  while #closed > 5 do
    table.remove(closed)
  end
  table.sort(closed, cmp_older_first)

  table.sort(active, cmp_older_first)
  table.sort(future, cmp_older_first)

  local display_sprints = {}
  for _, s in ipairs(closed) do
    table.insert(display_sprints, s)
  end
  for _, s in ipairs(active) do
    table.insert(display_sprints, s)
  end
  for _, s in ipairs(future) do
    table.insert(display_sprints, s)
  end

  local lines = {}
  table.insert(lines, string.format("Project: %s [%s]", project_name, project_key))
  table.insert(lines, string.format("Board: %s", board_name))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")
  table.insert(lines, "Sprints:")

  if #display_sprints == 0 then
    table.insert(lines, "  (none)")
    return table.concat(lines, "\n")
  end

  for _, sprint in ipairs(display_sprints) do
    table.sort(sprint.issues, function(a, b) return a.key < b.key end)
    local is_current = string.lower(sprint.state or "") == "active"
    local prefix = is_current and "  >>> " or "  - "
    local suffix = is_current and " <<< [CURRENT]" or ""
    table.insert(lines, string.format("%s%s [state:%s] [issues:%d]%s", prefix, sprint.name, sprint.state, #sprint.issues, suffix))
    if #sprint.issues == 0 then
      table.insert(lines, "      (no issues)")
    else
      for _, issue in ipairs(sprint.issues) do
        local issue_label = string.format(
          "[%s] %s [status:%s] [assignee:%s]",
          issue.key,
          issue.summary,
          issue.status,
          issue.assignee
        )
        issue_label = markdown_strike_if_done(issue_label, issue.status)
        table.insert(
          lines,
          "      - " .. issue_label
        )
      end
    end
  end

  return table.concat(lines, "\n")
end

local function jira_project_sprints_for_board(project_key, project_name, board_id, board_name)
  spinner_start("Jira: loading sprints ...")
  local sprint_list_cmd = { "acli", "jira", "board", "list-sprints", "--id", tostring(board_id), "--state", "active,future,closed", "--paginate", "--json" }
  run_cmd_async(
    sprint_list_cmd,
    function(output, code)
      if code ~= 0 then
        spinner_stop()
        jira_debug_log("jira_project_sprints:list-sprints:command-failed", sprint_list_cmd, output)
        vim.notify("Failed to load sprints:\n" .. output, vim.log.levels.ERROR)
        return
      end

      local sprints = {}
      local sprint_rows = {}

      local decoded = decode_json(output)
      if decoded then
        sprint_rows = extract_sprints(decoded)
      else
        local pages = decode_json_pages(output)
        if not pages then
          spinner_stop()
          jira_debug_log("jira_project_sprints:list-sprints:json-parse-failed", sprint_list_cmd, output)
          vim.notify("Could not parse sprint list JSON output", vim.log.levels.ERROR)
          return
        end

        local seen_sprint_ids = {}
        for _, page in ipairs(pages) do
          for _, row in ipairs(extract_sprints(page)) do
            local id = type(row) == "table" and row.id or nil
            if id ~= nil then
              local id_key = tostring(id)
              if not seen_sprint_ids[id_key] then
                seen_sprint_ids[id_key] = true
                table.insert(sprint_rows, row)
              end
            else
              table.insert(sprint_rows, row)
            end
          end
        end
      end

      for _, raw in ipairs(sprint_rows) do
        local sprint = extract_sprint_info(raw)
        if sprint then
          table.insert(sprints, sprint)
        end
      end

      if #sprints == 0 then
        spinner_stop()
        insert_block_at_cursor(build_project_sprints_report(project_key, project_name, board_name, sprints))
        return
      end

      spinner_start("Jira: loading sprint issues ...")
      local max_concurrency = 6
      local next_idx = 1
      local active = 0

      local function load_sprint_issues(sprint, done)
        local sprint_issue_cmd = {
          "acli", "jira", "sprint", "list-workitems",
          "--board", tostring(board_id),
          "--sprint", tostring(sprint.id),
          "--fields", "key,summary,status,assignee",
          "--paginate",
          "--json",
        }
        run_cmd_async(
          sprint_issue_cmd,
          function(issue_output, issue_code)
            if issue_code == 0 then
              local issue_decoded = decode_json(issue_output)
              if issue_decoded then
                for _, item in ipairs(extract_workitems(issue_decoded)) do
                  local key, summary = extract_key_summary(item)
                  if key then
                    local status, assignee = extract_status_assignee_parent(item)
                    table.insert(sprint.issues, {
                      key = clean_jira_text(key),
                      summary = clean_jira_text(summary),
                      status = clean_jira_text(status),
                      assignee = clean_jira_text(assignee),
                    })
                  end
                end
              else
                jira_debug_log(
                  "jira_project_sprints:list-workitems:json-parse-failed:sprint-" .. tostring(sprint.id),
                  sprint_issue_cmd,
                  issue_output
                )
              end
            else
              jira_debug_log(
                "jira_project_sprints:list-workitems:command-failed:sprint-" .. tostring(sprint.id),
                sprint_issue_cmd,
                issue_output
              )
            end
            done()
          end
        )
      end

      local function pump()
        while active < max_concurrency and next_idx <= #sprints do
          local sprint = sprints[next_idx]
          next_idx = next_idx + 1
          active = active + 1
          load_sprint_issues(sprint, function()
            active = active - 1
            if next_idx > #sprints and active == 0 then
              spinner_stop()
              insert_block_at_cursor(build_project_sprints_report(project_key, project_name, board_name, sprints))
              return
            end
            pump()
          end)
        end
      end

      pump()
    end
  )
end

local function jira_project_sprints(opts)
  opts = opts or {}
  spinner_start("Jira: loading projects ...")
  local project_list_cmd = { "acli", "jira", "project", "list", "--paginate", "--json" }
  run_cmd_async(project_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_project_sprints:project-list:command-failed", project_list_cmd, output)
      vim.notify("Failed to load Jira projects:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      spinner_stop()
      jira_debug_log("jira_project_sprints:project-list:json-parse-failed", project_list_cmd, output)
      vim.notify("Could not parse project list JSON output", vim.log.levels.ERROR)
      return
    end

    local entries = {}
    local project_by_entry = {}
    for _, project in ipairs(extract_projects(decoded)) do
      local key, name = extract_project_key_name(project)
      if key then
        local entry = string.format("%s | %s", clean_jira_text(key), clean_jira_text(name))
        table.insert(entries, entry)
        project_by_entry[entry] = { key = key, name = name }
      end
    end

    spinner_stop()
    if #entries == 0 then
      vim.notify("No Jira projects found", vim.log.levels.INFO)
      return
    end

    table.sort(entries)
    fzf.fzf_exec(entries, {
      prompt = "Jira Project> ",
      previewer = false,
      fzf_opts = { ["--ansi"] = false },
      actions = {
        ['default'] = function(selected)
          local entry = selected and selected[1]
          local project = entry and project_by_entry[entry] or nil
          if not project then
            return
          end

          spinner_start("Jira: loading boards ...")
          local board_search_cmd = { "acli", "jira", "board", "search", "--project", project.key, "--type", "scrum", "--paginate", "--json" }
          run_cmd_async(
            board_search_cmd,
            function(board_output, board_code)
              if board_code ~= 0 then
                spinner_stop()
                jira_debug_log("jira_project_sprints:board-search:command-failed", board_search_cmd, board_output)
                vim.notify("Failed to load boards:\n" .. board_output, vim.log.levels.ERROR)
                return
              end

              local board_decoded = decode_json(board_output)
              if not board_decoded then
                spinner_stop()
                jira_debug_log("jira_project_sprints:board-search:json-parse-failed", board_search_cmd, board_output)
                vim.notify("Could not parse board search JSON output", vim.log.levels.ERROR)
                return
              end

              local board_entries = {}
              local board_by_entry = {}
              for _, board in ipairs(extract_boards(board_decoded)) do
                local board_id, board_name = extract_board_id_name(board)
                if board_id then
                  local be = string.format("%s | %s", tostring(board_id), clean_jira_text(board_name))
                  table.insert(board_entries, be)
                  board_by_entry[be] = { id = board_id, name = board_name }
                end
              end

              spinner_stop()
              if #board_entries == 0 then
                vim.notify("No scrum boards found for project " .. project.key, vim.log.levels.WARN)
                return
              end

              if #board_entries == 1 then
                local b = board_by_entry[board_entries[1]]
                jira_project_sprints_for_board(project.key, project.name, b.id, b.name)
                return
              end

              table.sort(board_entries)
              fzf.fzf_exec(board_entries, {
                prompt = "Jira Board> ",
                previewer = false,
                fzf_opts = { ["--ansi"] = false },
                actions = {
                  ['default'] = function(board_selected)
                    local be = board_selected and board_selected[1]
                    local board = be and board_by_entry[be] or nil
                    if board then
                      jira_project_sprints_for_board(project.key, project.name, board.id, board.name)
                    end
                  end,
                },
              })
            end
          )
        end,
      },
    })
  end)
end

local function jira_search_ticket(opts)
  opts = opts or {}
  local initial_jql = opts.jql or opts.args or opts.query
  if type(initial_jql) == "string" and vim.trim(initial_jql) ~= "" then
    jira_search_by_jql(vim.trim(initial_jql), view_jira_workitem)
    return
  end

  vim.ui.input({ prompt = "JQL> " }, function(input)
    if not input then
      return
    end
    input = vim.trim(input)
    if input == "" then
      return
    end
    jira_search_by_jql(input, view_jira_workitem)
  end)
end

local function jira_text_search_ticket(opts)
  opts = opts or {}
  local initial_text = opts.text or opts.args or opts.query
  if type(initial_text) == "string" and vim.trim(initial_text) ~= "" then
    jira_search_by_jql(wrap_text_as_jql(vim.trim(initial_text)), view_jira_workitem)
    return
  end

  vim.ui.input({ prompt = "Text> " }, function(input)
    if not input then
      return
    end
    input = vim.trim(input)
    if input == "" then
      return
    end
    jira_search_by_jql(wrap_text_as_jql(input), view_jira_workitem)
  end)
end

local function jira_search_ticket_open_link(opts)
  opts = opts or {}
  local initial_jql = opts.jql or opts.args or opts.query
  if type(initial_jql) == "string" and vim.trim(initial_jql) ~= "" then
    jira_search_by_jql(vim.trim(initial_jql), open_jira_workitem_link)
    return
  end

  vim.ui.input({ prompt = "JQL> " }, function(input)
    if not input then
      return
    end
    input = vim.trim(input)
    if input == "" then
      return
    end
    jira_search_by_jql(input, open_jira_workitem_link)
  end)
end

local function jira_text_search_ticket_open_link(opts)
  opts = opts or {}
  local initial_text = opts.text or opts.args or opts.query
  if type(initial_text) == "string" and vim.trim(initial_text) ~= "" then
    jira_search_by_jql(wrap_text_as_jql(vim.trim(initial_text)), open_jira_workitem_link)
    return
  end

  vim.ui.input({ prompt = "Text> " }, function(input)
    if not input then
      return
    end
    input = vim.trim(input)
    if input == "" then
      return
    end
    jira_search_by_jql(wrap_text_as_jql(input), open_jira_workitem_link)
  end)
end

local unicode_symbols = {
  { symbol = "✓", name = "checkmark", aliases = "check tick done yes success" },
  { symbol = "✅", name = "done", aliases = "complete finished resolved shipped" },
  { symbol = "☑", name = "verified done", aliases = "verified checked validated complete" },
  { symbol = "⏳", name = "in progress", aliases = "progress pending running loading wip hourglass" },
  { symbol = "🟨", name = "blocked risked", aliases = "blocked risk warning hold" },
  { symbol = "⛔", name = "blocked hard", aliases = "blocked stop cannot proceed hardblock" },
  { symbol = "⏸", name = "paused", aliases = "pause on hold waiting suspended" },
  { symbol = "🧪", name = "in testing", aliases = "testing qa verify test" },
  { symbol = "🚀", name = "shipped", aliases = "release deployed launched done" },
  { symbol = "♻", name = "rework refactor", aliases = "rework refactor cleanup rewrite" },
  { symbol = "❌", name = "canceled", aliases = "cancelled canceled dropped wontfix" },
  { symbol = "✔", name = "heavy checkmark", aliases = "check tick done yes success" },
  { symbol = "✗", name = "cross mark", aliases = "x wrong no fail" },
  { symbol = "✘", name = "heavy cross mark", aliases = "x wrong no fail" },
  { symbol = "•", name = "bullet", aliases = "dot list" },
  { symbol = "🔥", name = "urgent", aliases = "urgent asap critical high priority" },
  { symbol = "⬆", name = "high priority", aliases = "priority high important" },
  { symbol = "➖", name = "medium priority", aliases = "priority medium normal" },
  { symbol = "⬇", name = "low priority", aliases = "priority low minor" },
  { symbol = "📌", name = "pinned", aliases = "pin important sticky bookmark" },
  { symbol = "🎯", name = "goal", aliases = "goal objective target" },
  { symbol = "🗺", name = "roadmap item", aliases = "roadmap plan milestone" },
  { symbol = "🧭", name = "decision needed", aliases = "decision needed direction choose" },
  { symbol = "🧱", name = "dependency", aliases = "dependency blocker prerequisite" },
  { symbol = "🔀", name = "tradeoff", aliases = "tradeoff compromise option branch" },
  { symbol = "🛠", name = "action item", aliases = "todo task action next step" },
  { symbol = "🗓", name = "scheduled", aliases = "scheduled calendar meeting date" },
  { symbol = "👥", name = "attendees", aliases = "attendees people stakeholders participants" },
  { symbol = "📝", name = "notes", aliases = "notes meeting notes memo" },
  { symbol = "❓", name = "open question", aliases = "question unknown unresolved ask" },
  { symbol = "💡", name = "idea", aliases = "idea brainstorm concept suggestion" },
  { symbol = "⚖", name = "decision made", aliases = "decision decided ruling outcome" },
  { symbol = "➡", name = "next step", aliases = "next step follow-up action" },
  { symbol = "🙋", name = "owner needed", aliases = "owner needed assign ownership" },
  { symbol = "🐛", name = "bug", aliases = "bug defect issue error" },
  { symbol = "🔍", name = "investigation", aliases = "investigate debugging analysis triage" },
  { symbol = "📈", name = "metric improved", aliases = "metric improved up trend gain" },
  { symbol = "📉", name = "regression", aliases = "regression metric down degraded" },
  { symbol = "⚠", name = "warning", aliases = "warning caution risk attention" },
  { symbol = "🧨", name = "incident", aliases = "incident outage production fire sev" },
  { symbol = "🩹", name = "hotfix", aliases = "hotfix quick fix patch urgent" },
  { symbol = "🔒", name = "security", aliases = "security vuln vulnerability auth privacy" },
  { symbol = "🧬", name = "root cause", aliases = "root cause rca postmortem reason" },
  { symbol = "📦", name = "release build", aliases = "release build package artifact" },
  { symbol = "⏱", name = "estimate time spent", aliases = "estimate timing duration effort spent" },
  { symbol = "📅", name = "due date", aliases = "due date deadline target date" },
  { symbol = "🔔", name = "reminder", aliases = "reminder notify alert ping" },
  { symbol = "↩", name = "follow-up", aliases = "follow-up revisit callback return" },
  { symbol = "🔁", name = "recurring", aliases = "recurring repeat routine cyclic" },
  { symbol = "📬", name = "waiting on response", aliases = "waiting response pending reply external" },
  { symbol = "→", name = "right arrow", aliases = "arrow next forward" },
  { symbol = "←", name = "left arrow", aliases = "arrow back previous" },
  { symbol = "↑", name = "up arrow", aliases = "arrow" },
  { symbol = "↓", name = "down arrow", aliases = "arrow" },
  { symbol = "↔", name = "left right arrow", aliases = "arrow horizontal" },
  { symbol = "⇒", name = "double right arrow", aliases = "implies" },
  { symbol = "∞", name = "infinity", aliases = "math endless" },
  { symbol = "±", name = "plus minus", aliases = "math" },
  { symbol = "≈", name = "approximately equal", aliases = "math almost equal" },
  { symbol = "≠", name = "not equal", aliases = "math inequality" },
  { symbol = "≤", name = "less than or equal", aliases = "math" },
  { symbol = "≥", name = "greater than or equal", aliases = "math" },
  { symbol = "°", name = "degree", aliases = "temperature angle" },
  { symbol = "©", name = "copyright", aliases = "legal" },
  { symbol = "®", name = "registered", aliases = "legal" },
  { symbol = "™", name = "trademark", aliases = "legal" },
}

local function pick_unicode_symbol(opts)
  opts = opts or {}
  local entries = {}

  for _, item in ipairs(unicode_symbols) do
    table.insert(entries, string.format("%s\t%s\t%s", item.symbol, item.name, item.aliases))
  end

  fzf.fzf_exec(entries, {
    prompt = "Insert Symbol> ",
    query = opts.query,
    previewer = false,
    actions = {
      ['default'] = function(selected)
        local fields = vim.split(selected[1], "\t")
        local symbol = fields[1]
        if symbol and symbol ~= "" then
          insert_text_at_cursor(symbol)
        end
      end,
    },
  })
end

-- Register the functions with fzf-lua
require('fzf-lua').projects = browse_source_dirs
require('fzf-lua').nvim_config = browse_nvim_conf
require('fzf-lua').current_file_dir = browse_current_file_dir
require('fzf-lua').grep_current_file_dir = grep_current_file_dir
require('fzf-lua').modules = browse_streamsdk_modules
require('fzf-lua').magrep = grep_in_directory
require('fzf-lua').dircommits = dir_commits
require('fzf-lua').vimwiki_files = browse_vimwiki_files
require('fzf-lua').vimwiki_grep = grep_vimwiki
require('fzf-lua').symbols = pick_unicode_symbol
require('fzf-lua').jira_search_ticket = jira_search_ticket
require('fzf-lua').jira_text_search_ticket = jira_text_search_ticket
require('fzf-lua').jira_search_ticket_open_link = jira_search_ticket_open_link
require('fzf-lua').jira_text_search_ticket_open_link = jira_text_search_ticket_open_link
require('fzf-lua').jira_project_epics_stories = jira_project_epics_stories
require('fzf-lua').jira_project_sprints = jira_project_sprints
require('fzf-lua').jira_preview_ticket = jira_preview_ticket
require('fzf-lua').jira_open_ticket = jira_open_ticket

vim.api.nvim_create_user_command("Symbols", function(opts)
  require('fzf-lua').symbols({ query = opts.args })
end, {
  nargs = "*",
  desc = "Fuzzy find a Unicode symbol and insert it at cursor",
})

vim.api.nvim_create_user_command("VimwikiFiles", function(opts)
  require('fzf-lua').vimwiki_files({ query = opts.args })
end, {
  nargs = "*",
  desc = "Fuzzy find files in Vimwiki folder",
})

vim.api.nvim_create_user_command("VimwikiGrep", function(opts)
  require('fzf-lua').vimwiki_grep({ search = opts.args })
end, {
  nargs = "*",
  desc = "Search text in Vimwiki folder",
})

vim.api.nvim_create_user_command("JiraSearchTicket", function(opts)
  require('fzf-lua').jira_search_ticket({ jql = opts.args })
end, {
  nargs = "*",
  desc = "jira_search_ticket: Search Jira by JQL and insert selected ticket details",
})

vim.api.nvim_create_user_command("JiraTextSearchTicket", function(opts)
  require('fzf-lua').jira_text_search_ticket({ text = opts.args })
end, {
  nargs = "*",
  desc = "jira_text_search_ticket: Search Jira by text (wraps as text ~ \"...\")",
})

vim.api.nvim_create_user_command("JiraSearchTicketOpenLink", function(opts)
  require('fzf-lua').jira_search_ticket_open_link({ jql = opts.args })
end, {
  nargs = "*",
  desc = "jira_search_ticket_open_link: Search Jira by JQL and open selected ticket link",
})

vim.api.nvim_create_user_command("JiraTextSearchTicketOpenLink", function(opts)
  require('fzf-lua').jira_text_search_ticket_open_link({ text = opts.args })
end, {
  nargs = "*",
  desc = "jira_text_search_ticket_open_link: Search Jira by text and open selected ticket link",
})

vim.api.nvim_create_user_command("JiraProjectEpicsStories", function(opts)
  require('fzf-lua').jira_project_epics_stories({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_project_epics_stories: Pick project, dump epics/stories excluding Done by default",
})

vim.api.nvim_create_user_command("JiraProjectEpicsStoriesExcludeDone", function(opts)
  require('fzf-lua').jira_project_epics_stories({ query = opts.args, exclude_done = true })
end, {
  nargs = "*",
  desc = "jira_project_epics_stories: Pick project, dump epics/stories excluding Done",
})

vim.api.nvim_create_user_command("JiraProjectEpicsStoriesIncludeDone", function(opts)
  require('fzf-lua').jira_project_epics_stories({ query = opts.args, exclude_done = false })
end, {
  nargs = "*",
  desc = "jira_project_epics_stories: Pick project, dump epics/stories including Done",
})

vim.api.nvim_create_user_command("JiraProjectSprints", function(opts)
  require('fzf-lua').jira_project_sprints({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_project_sprints: Pick project, then dump issues grouped by sprint",
})

vim.api.nvim_create_user_command("JiraPreviewTicket", function(opts)
  require('fzf-lua').jira_preview_ticket({ args = opts.args })
end, {
  nargs = "*",
  desc = "jira_preview_ticket: Preview ticket in Neovim (arg or word under cursor)",
})

vim.api.nvim_create_user_command("JiraOpenTicket", function(opts)
  require('fzf-lua').jira_open_ticket({ args = opts.args })
end, {
  nargs = "*",
  desc = "jira_open_ticket: Open ticket in Jira web (arg or word under cursor)",
})

require('fzf-lua').setup {
  -- fzf_bin         = 'sk',            -- use skim instead of fzf?
                                        -- https://github.com/lotabout/skim
  global_resume      = true,            -- enable global `resume`?
                                        -- can also be sent individually:
                                        -- `<any_function>.({ gl ... })`
  global_resume_query = true,           -- include typed query in `resume`?
  winopts = {
    -- split         = "belowright new",-- open in a split instead?
                                        -- "belowright new"  : split below
                                        -- "aboveleft new"   : split above
                                        -- "belowright vnew" : split right
                                        -- "aboveleft vnew   : split left
    -- Only valid when using a float window
    -- (i.e. when 'split' is not defined, default)
    height           = 0.85,            -- window height
    width            = 0.80,            -- window width
    row              = 0.35,            -- window row position (0=top, 1=bottom)
    col              = 0.50,            -- window col position (0=left, 1=right)
    -- border argument passthrough to nvim_open_win(), also used
    -- to manually draw the border characters around the preview
    -- window, can be set to 'false' to remove all borders or to
    -- 'none', 'single', 'double', 'thicc' or 'rounded' (default)
    border           = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
    fullscreen       = false,           -- start fullscreen?
    -- highlights should optimally be set by the colorscheme using
    -- FzfLuaXXX highlights. If your colorscheme doesn't set these
    -- or you wish to override its defaults use these:
    --[[ hl = {
      normal         = 'Normal',        -- window normal color (fg+bg)
      border         = 'FloatBorder',   -- border color
      help_normal    = 'Normal',        -- <F1> window normal
      help_border    = 'FloatBorder',   -- <F1> window border
      -- Only used with the builtin previewer:
      cursor         = 'Cursor',        -- cursor highlight (grep/LSP matches)
      cursorline     = 'CursorLine',    -- cursor line
      cursorlinenr   = 'CursorLineNr',  -- cursor line number
      search         = 'IncSearch',     -- search matches (ctags|help)
      title          = 'Normal',        -- preview border title (file/buffer)
      -- Only used with 'winopts.preview.scrollbar = 'float'
      scrollfloat_e  = 'PmenuSbar',     -- scrollbar "empty" section highlight
      scrollfloat_f  = 'PmenuThumb',    -- scrollbar "full" section highlight
      -- Only used with 'winopts.preview.scrollbar = 'border'
      scrollborder_e = 'FloatBorder',   -- scrollbar "empty" section highlight
      scrollborder_f = 'FloatBorder',   -- scrollbar "full" section highlight
    }, ]]
    preview = {
      -- default     = 'bat',           -- override the default previewer?
                                        -- default uses the 'builtin' previewer
      border         = 'border',        -- border|noborder, applies only to
                                        -- native fzf previewers (bat/cat/git/etc)
      wrap           = 'nowrap',        -- wrap|nowrap
      hidden         = 'nohidden',      -- hidden|nohidden
      vertical       = 'down:45%',      -- up|down:size
      horizontal     = 'right:60%',     -- right|left:size
      layout         = 'vertical',          -- horizontal|vertical|flex
      flip_columns   = 120,             -- #cols to switch to horizontal on flex
      -- Only used with the builtin previewer:
      title          = true,            -- preview border title (file/buf)?
      title_pos      = "left",          -- left|center|right, title alignment
      scrollbar      = 'false',         -- `false` or string:'float|border'
                                        -- float:  in-window floating border
                                        -- border: in-border chars (see below)
      scrolloff      = '-2',            -- float scrollbar offset from right
                                        -- applies only when scrollbar = 'float'
      scrollchars    = {'█', '' },      -- scrollbar chars ({ <full>, <empty> }
                                        -- applies only when scrollbar = 'border'
      delay          = 100,             -- delay(ms) displaying the preview
                                        -- prevents lag on fast scrolling
      winopts = {                       -- builtin previewer window options
        number            = true,
        relativenumber    = false,
        cursorline        = true,
        cursorlineopt     = 'both',
        cursorcolumn      = false,
        signcolumn        = 'no',
        list              = false,
        foldenable        = false,
        foldmethod        = 'manual',
      },
    },
    on_create = function()
      -- called once upon creation of the fzf main window
      -- can be used to add custom fzf-lua mappings, e.g:
      --   vim.api.nvim_buf_set_keymap(0, "t", "<C-j>", "<Down>",
      --     { silent = true, noremap = true })
    end,
  },
  keymap = {
    -- These override the default tables completely
    -- no need to set to `false` to disable a bind
    -- delete or modify is sufficient
    builtin = {
      -- neovim `:tmap` mappings for the fzf win
      ["<F1>"]        = "toggle-help",
      ["<F2>"]        = "toggle-fullscreen",
      -- Only valid with the 'builtin' previewer
      ["<F3>"]        = "toggle-preview-wrap",
      ["<F4>"]        = "toggle-preview",
      -- Rotate preview clockwise/counter-clockwise
      ["<F5>"]        = "toggle-preview-ccw",
      ["<F6>"]        = "toggle-preview-cw",
      ["<S-down>"]    = "preview-page-down",
      ["<S-up>"]      = "preview-page-up",
      ["<S-left>"]    = "preview-page-reset",
    },
    fzf = {
      -- fzf '--bind=' options
      ["ctrl-z"]      = "abort",
      ["ctrl-u"]      = "unix-line-discard",
      ["ctrl-f"]      = "half-page-down",
      ["ctrl-b"]      = "half-page-up",
      ["ctrl-a"]      = "beginning-of-line",
      ["ctrl-e"]      = "end-of-line",
      ["alt-a"]       = "toggle-all",
      -- Only valid with fzf previewers (bat/cat/git/etc)
      ["f3"]          = "toggle-preview-wrap",
      ["f4"]          = "toggle-preview",
      ["shift-down"]  = "preview-page-down",
      ["shift-up"]    = "preview-page-up",
    },
  },
  actions = {
    -- These override the default tables completely
    -- no need to set to `false` to disable an action
    -- delete or modify is sufficient
    files = {
      -- providers that inherit these actions:
      --   files, git_files, git_status, grep, lsp
      --   oldfiles, quickfix, loclist, tags, btags
      --   args
      -- default action opens a single selection
      -- or sends multiple selection to quickfix
      -- replace the default action with the below
      -- to open all files whether single or multiple
      -- ["default"]     = actions.file_edit,
      ["default"]     = actions.file_edit_or_qf,
      ["ctrl-s"]      = actions.file_split,
      ["ctrl-v"]      = actions.file_vsplit,
      ["ctrl-t"]      = actions.file_tabedit,
      ["alt-q"]       = actions.file_sel_to_qf,
      ["alt-l"]       = actions.file_sel_to_ll,
      ["ctrl-g"]      = actions.toggle_ignore,
    },
    buffers = {
      -- providers that inherit these actions:
      --   buffers, tabs, lines, blines
      ["default"]     = actions.buf_edit,
      ["ctrl-s"]      = actions.buf_split,
      ["ctrl-v"]      = actions.buf_vsplit,
      ["ctrl-t"]      = actions.buf_tabedit,
    }
  },
  fzf_opts = {
    -- options are sent as `<left>=<right>`
    -- set to `false` to remove a flag
    -- set to '' for a non-value flag
    -- for raw args use `fzf_args` instead
    ['--ansi']        = '',
    ['--info']        = 'inline',
    ['--height']      = '100%',
    ['--layout']      = 'reverse',
    ['--border']      = 'none',
  },
  -- fzf '--color=' options (optional)
  fzf_colors = {
      -- ["fg"]          = { "fg", "CursorLine" },
      -- ["bg"]          = { "bg", "Normal" },
      -- ["hl"]          = { "fg", "Comment" },
      -- ["fg+"]         = { "fg", "Normal" },
      -- ["bg+"]         = { "bg", "CursorLine" },
      -- ["hl+"]         = { "fg", "Statement" },
      -- ["info"]        = { "fg", "PreProc" },
      -- ["prompt"]      = { "fg", "Conditional" },
      -- ["pointer"]     = { "fg", "Exception" },
      -- ["marker"]      = { "fg", "Keyword" },
      -- ["spinner"]     = { "fg", "Label" },
      -- ["header"]      = { "fg", "Comment" },
      ["gutter"]      = { "bg", "Normal" },
  },
  previewers = {
    cat = {
      cmd             = "cat",
      args            = "--number",
    },
    bat = {
      cmd             = "bat",
      args            = "--style=numbers,changes --color always",
      theme           = 'Coldark-Dark', -- bat preview theme (bat --list-themes)
      config          = nil,            -- nil uses $BAT_CONFIG_PATH
    },
    head = {
      cmd             = "head",
      args            = nil,
    },
    git_diff = {
      cmd_deleted     = "git diff --color HEAD --",
      cmd_modified    = "git diff --color HEAD",
      cmd_untracked   = "git diff --color --no-index /dev/null",
      -- uncomment if you wish to use git-delta as pager
      -- can also be set under 'git.status.preview_pager'
      -- pager        = "delta --width=$FZF_PREVIEW_COLUMNS",
    },
    man = {
      -- NOTE: remove the `-c` flag when using man-db
      cmd             = "man -c %s | col -bx",
    },
    builtin = {
      syntax          = true,         -- preview syntax highlight?
      syntax_limit_l  = 0,            -- syntax limit (lines), 0=nolimit
      syntax_limit_b  = 1024*1024,    -- syntax limit (bytes), 0=nolimit
      limit_b         = 1024*1024*10, -- preview limit (bytes), 0=nolimit
      -- preview extensions using a custom shell command:
      -- for example, use `viu` for image previews
      -- will do nothing if `viu` isn't executable
      extensions      = {
        -- neovim terminal only supports `viu` block output
        ["png"]       = { "viu", "-b" },
        ["jpg"]       = { "ueberzug" },
      },
      -- if using `ueberzug` in the above extensions map
      -- set the default image scaler, possible scalers:
      --   false (none), "crop", "distort", "fit_contain",
      --   "contain", "forced_cover", "cover"
      -- https://github.com/seebye/ueberzug
      ueberzug_scaler = "cover",
    },
  },
  -- provider setup
  files = {
    -- previewer      = "bat",          -- uncomment to override previewer
                                        -- (name from 'previewers' table)
                                        -- set to 'false' to disable
    prompt            = 'Files❯ ',
    multiprocess      = true,           -- run command in a separate process
    git_icons         = true,           -- show git icons?
    file_icons        = true,           -- show file icons?
    color_icons       = true,           -- colorize file|git icons
    -- path_shorten   = 1,              -- 'true' or number, shorten path?
    -- executed command priority is 'cmd' (if exists)
    -- otherwise auto-detect prioritizes `fd`:`rg`:`find`
    -- default options are controlled by 'fd|rg|find|_opts'
    -- NOTE: 'find -printf' requires GNU find
    -- cmd            = "find . -type f -printf '%P\n'",
    find_opts         = [[-type f -not -path '*/\.git/*' -printf '%P\n']],
    rg_opts           = "--color=never --files --hidden --follow -g '!.git'",
    fd_opts           = "--color=never --type f --hidden --follow --exclude .git",
    actions = {
      -- inherits from 'actions.files', here we can override
      -- or set bind to 'false' to disable a default action
      ["default"]     = actions.file_edit,
      -- custom actions are available too
      ["ctrl-y"]      = function(selected) print(selected[1]) end,
    }
  },
  git = {
    files = {
      prompt        = 'GitFiles❯ ',
      cmd           = 'git ls-files --exclude-standard',
      multiprocess  = true,           -- run command in a separate process
      git_icons     = true,           -- show git icons?
      file_icons    = true,           -- show file icons?
      color_icons   = true,           -- colorize file|git icons
      -- force display the cwd header line regardles of your current working
      -- directory can also be used to hide the header when not wanted
      -- show_cwd_header = true
    },
    status = {
      prompt        = 'GitStatus❯ ',
      -- consider using `git status -su` if you wish to see
      -- untracked files individually under their subfolders
      cmd           = "git status -s",
      file_icons    = true,
      git_icons     = true,
      color_icons   = true,
      previewer     = "git_diff",
      -- uncomment if you wish to use git-delta as pager
      --preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
      actions = {
        -- actions inherit from 'actions.files' and merge
        ["right"]   = { actions.git_unstage, actions.resume },
        ["left"]    = { actions.git_stage, actions.resume },
      },
    },
    commits = {
      prompt        = 'Commits❯ ',
      cmd           = "git log --color --pretty=format:'%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset'",
      preview       = "git show --pretty='%Cred%H%n%Cblue%an <%ae>%n%C(yellow)%cD%n%Cgreen%s' --color {1}",
      -- uncomment if you wish to use git-delta as pager
      --preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
      actions = {
        ["default"] = actions.git_checkout,
      },
    },
    bcommits = {
      prompt        = 'BCommits❯ ',
      -- default preview shows a git diff vs the previous commit
      -- if you prefer to see the entire commit you can use:
      --   git show --color {1} --rotate-to=<file>
      --   {1}    : commit SHA (fzf field index expression)
      --   <file> : filepath placement within the commands
      cmd           = "git log --color --pretty=format:'%C(yellow)%h%Creset %Cgreen(%><(12)%cr%><|(12))%Creset %s %C(blue)<%an>%Creset' <file>",
      preview       = "git diff --color {1}~1 {1} -- <file>",
      -- uncomment if you wish to use git-delta as pager
      --preview_pager = "delta --width=$FZF_PREVIEW_COLUMNS",
      actions = {
        ["default"] = actions.git_buf_edit,
        ["ctrl-s"]  = actions.git_buf_split,
        ["ctrl-v"]  = actions.git_buf_vsplit,
        ["ctrl-t"]  = actions.git_buf_tabedit,
      },
    },
    branches = {
      prompt          = 'Branches❯ ',
      cmd             = "git branch --all --color",
      preview         = "git log --graph --pretty=oneline --abbrev-commit --color {1}",
      actions = {
        ["default"] = actions.git_switch,
      },
    },
    stash = {
      prompt          = 'Stash> ',
      cmd             = "git --no-pager stash list",
      preview         = "git --no-pager stash show --patch --color {1}",
      actions = {
        ["default"]   = actions.git_stash_apply,
        ["ctrl-x"]    = { actions.git_stash_drop, actions.resume },
      },
      fzf_opts = {
        ["--no-multi"]  = '',
        ['--delimiter'] = "'[:]'",
      },
    },
    icons = {
      ["M"]           = { icon = "M", color = "yellow" },
      ["D"]           = { icon = "D", color = "red" },
      ["A"]           = { icon = "A", color = "green" },
      ["R"]           = { icon = "R", color = "yellow" },
      ["C"]           = { icon = "C", color = "yellow" },
      ["T"]           = { icon = "T", color = "magenta" },
      ["?"]           = { icon = "?", color = "magenta" },
      -- override git icons?
      -- ["M"]        = { icon = "★", color = "red" },
      -- ["D"]        = { icon = "✗", color = "red" },
      -- ["A"]        = { icon = "+", color = "green" },
    },
  },
  grep = {
    prompt            = 'Rg❯ ',
    input_prompt      = 'Grep For❯ ',
    multiprocess      = true,           -- run command in a separate process
    git_icons         = true,           -- show git icons?
    file_icons        = true,           -- show file icons?
    color_icons       = true,           -- colorize file|git icons
    -- executed command priority is 'cmd' (if exists)
    -- otherwise auto-detect prioritizes `rg` over `grep`
    -- default options are controlled by 'rg|grep_opts'
    -- cmd            = "rg --vimgrep",
    grep_opts         = "--binary-files=without-match --line-number --recursive --color=auto --perl-regexp",
    rg_opts           = "--column --line-number --no-heading --color=always --smart-case --max-columns=512 --no-ignore-vcs",
    -- set to 'true' to always parse globs in both 'grep' and 'live_grep'
    -- search strings will be split using the 'glob_separator' and translated
    -- to '--iglob=' arguments, requires 'rg'
    -- can still be used when 'false' by calling 'live_grep_glob' directly
    rg_glob           = false,        -- default to glob parsing?
    glob_flag         = "--iglob",    -- for case sensitive globs use '--glob'
    glob_separator    = "%s%-%-",     -- query separator pattern (lua): ' --'
    -- advanced usage: for custom argument parsing define
    -- 'rg_glob_fn' to return a pair:
    --   first returned argument is the new search query
    --   second returned argument are addtional rg flags
    -- rg_glob_fn = function(query, opts)
    --   ...
    --   return new_query, flags
    -- end,
    actions = {
      -- actions inherit from 'actions.files' and merge
      -- this action toggles between 'grep' and 'live_grep'
      ["ctrl-g"]      = { actions.grep_lgrep }
    },
    no_header             = false,    -- hide grep|cwd header?
    no_header_i           = false,    -- hide interactive header?
  },
  args = {
    prompt            = 'Args❯ ',
    files_only        = true,
    -- actions inherit from 'actions.files' and merge
    actions           = { ["ctrl-x"] = { actions.arg_del, actions.resume } }
  },
  oldfiles = {
    prompt            = 'History❯ ',
    cwd_only          = false,
    stat_file         = true,         -- verify files exist on disk
    include_current_session = false,  -- include bufs from current session
  },
  buffers = {
    prompt            = 'Buffers❯ ',
    file_icons        = true,         -- show file icons?
    color_icons       = true,         -- colorize file|git icons
    sort_lastused     = true,         -- sort buffers() by last used
    actions = {
      -- actions inherit from 'actions.buffers' and merge
      -- by supplying a table of functions we're telling
      -- fzf-lua to not close the fzf window, this way we
      -- can resume the buffers picker on the same window
      -- eliminating an otherwise unaesthetic win "flash"
      ["ctrl-x"]      = { actions.buf_del, actions.resume },
    }
  },
  tabs = {
    prompt            = 'Tabs❯ ',
    tab_title         = "Tab",
    tab_marker        = "<<",
    file_icons        = true,         -- show file icons?
    color_icons       = true,         -- colorize file|git icons
    actions = {
      -- actions inherit from 'actions.buffers' and merge
      ["default"]     = actions.buf_switch,
      ["ctrl-x"]      = { actions.buf_del, actions.resume },
    },
    fzf_opts = {
      -- hide tabnr
      ['--delimiter'] = "'[\\):]'",
      ["--with-nth"]  = '2..',
    },
  },
  lines = {
    previewer         = "builtin",    -- set to 'false' to disable
    prompt            = 'Lines❯ ',
    show_unlisted     = false,        -- exclude 'help' buffers
    no_term_buffers   = true,         -- exclude 'term' buffers
    fzf_opts = {
      -- do not include bufnr in fuzzy matching
      -- tiebreak by line no.
      ['--delimiter'] = "'[\\]:]'",
      ["--nth"]       = '2..',
      ["--tiebreak"]  = 'index',
    },
    -- actions inherit from 'actions.buffers' and merge
    actions = {
      ["default"]     = actions.buf_edit_or_qf,
      ["alt-q"]       = actions.buf_sel_to_qf,
      ["alt-l"]       = actions.buf_sel_to_ll
    },
  },
  blines = {
    previewer         = "builtin",    -- set to 'false' to disable
    prompt            = 'BLines❯ ',
    show_unlisted     = true,         -- include 'help' buffers
    no_term_buffers   = false,        -- include 'term' buffers
    fzf_opts = {
      -- hide filename, tiebreak by line no.
      ['--delimiter'] = "'[\\]:]'",
      ["--with-nth"]  = '2..',
      ["--tiebreak"]  = 'index',
    },
    -- actions inherit from 'actions.buffers' and merge
    actions = {
      ["default"]     = actions.buf_edit_or_qf,
      ["alt-q"]       = actions.buf_sel_to_qf,
      ["alt-l"]       = actions.buf_sel_to_ll
    },
  },
  tags = {
    prompt                = 'Tags❯ ',
    ctags_file            = "tags",
    multiprocess          = true,
    file_icons            = true,
    git_icons             = true,
    color_icons           = true,
    -- 'tags_live_grep' options, `rg` prioritizes over `grep`
    rg_opts               = "--no-heading --color=always --smart-case",
    grep_opts             = "--color=auto --perl-regexp",
    actions = {
      -- actions inherit from 'actions.files' and merge
      -- this action toggles between 'grep' and 'live_grep'
      ["ctrl-g"]          = { actions.grep_lgrep }
    },
    no_header             = false,    -- hide grep|cwd header?
    no_header_i           = false,    -- hide interactive header?
  },
  btags = {
    prompt                = 'BTags❯ ',
    ctags_file            = "tags",
    ctags_autogen         = false,    -- dynamically generate ctags each call
    multiprocess          = true,
    file_icons            = true,
    git_icons             = true,
    color_icons           = true,
    rg_opts               = "--no-heading --color=always",
    grep_opts             = "--color=auto --perl-regexp",
    fzf_opts = {
      ['--delimiter']     = "'[\\]:]'",
      ["--with-nth"]      = '2..',
      ["--tiebreak"]      = 'index',
    },
    -- actions inherit from 'actions.files'
  },
  colorschemes = {
    prompt            = 'Colorschemes❯ ',
    live_preview      = true,       -- apply the colorscheme on preview?
    actions           = { ["default"] = actions.colorscheme, },
    winopts           = { height = 0.55, width = 0.30, },
    post_reset_cb     = function()
      -- reset statusline highlights after
      -- a live_preview of the colorscheme
      -- require('feline').reset_highlights()
    end,
  },
  quickfix = {
    file_icons        = true,
    git_icons         = true,
  },
  lsp = {
    prompt_postfix    = '❯ ',       -- will be appended to the LSP label
                                    -- to override use 'prompt' instead
    cwd_only          = false,      -- LSP/diagnostics for cwd only?
    async_or_timeout  = 5000,       -- timeout(ms) or 'true' for async calls
    file_icons        = true,
    git_icons         = false,
    -- settings for 'lsp_{document|workspace|lsp_live_workspace}_symbols'
    symbols = {
        async_or_timeout  = true,       -- symbols are async by default
        symbol_style      = 1,          -- style for document/workspace symbols
                                        -- false: disable,    1: icon+kind
                                        --     2: icon only,  3: kind only
                                        -- NOTE: icons are extracted from
                                        -- vim.lsp.protocol.CompletionItemKind
        -- colorize using nvim-cmp's CmpItemKindXXX highlights
        -- can also be set to 'TS' for treesitter highlights ('TSProperty', etc)
        -- or 'false' to disable highlighting
        symbol_hl_prefix  = "CmpItemKind",
        -- additional symbol formatting, works with or without style
        symbol_fmt        = function(s) return "["..s.."]" end,
    },
    code_actions = {
        prompt            = 'Code Actions> ',
        ui_select         = true,       -- use 'vim.ui.select'?
        async_or_timeout  = 5000,
        winopts = {
            row           = 0.40,
            height        = 0.35,
            width         = 0.60,
        },
    }
  },
  diagnostics ={
    prompt            = 'Diagnostics❯ ',
    cwd_only          = false,
    file_icons        = true,
    git_icons         = false,
    diag_icons        = true,
    icon_padding      = '',     -- add padding for wide diagnostics signs
    -- by default icons and highlights are extracted from 'DiagnosticSignXXX'
    -- and highlighted by a highlight group of the same name (which is usually
    -- set by your colorscheme, for more info see:
    --   :help DiagnosticSignHint'
    --   :help hl-DiagnosticSignHint'
    -- only uncomment below if you wish to override the signs/highlights
    -- define only text, texthl or both (':help sign_define()' for more info)
    -- signs = {
    --   ["Error"] = { text = "", texthl = "DiagnosticError" },
    --   ["Warn"]  = { text = "", texthl = "DiagnosticWarn" },
    --   ["Info"]  = { text = "", texthl = "DiagnosticInfo" },
    --   ["Hint"]  = { text = "", texthl = "DiagnosticHint" },
    -- },
    -- limit to specific severity, use either a string or num:
    --   1 or "hint"
    --   2 or "information"
    --   3 or "warning"
    --   4 or "error"
    -- severity_only:   keep any matching exact severity
    -- severity_limit:  keep any equal or more severe (lower)
    -- severity_bound:  keep any equal or less severe (higher)
  },
  -- uncomment to use the old help previewer which used a
  -- minimized help window to generate the help tag preview
  -- helptags = { previewer = "help_tags" },
  -- uncomment to use `man` command as native fzf previewer
  -- (instead of using a neovim floating window)
  -- manpages = { previewer = "man_native" },
  -- 
  -- optional override of file extension icon colors
  -- available colors (terminal):
  --    clear, bold, black, red, green, yellow
  --    blue, magenta, cyan, grey, dark_grey, white
  file_icon_colors = {
    ["sh"] = "green",
  },
  -- padding can help kitty term users with
  -- double-width icon rendering
  file_icon_padding = '',
  -- uncomment if your terminal/font does not support unicode character
  -- 'EN SPACE' (U+2002), the below sets it to 'NBSP' (U+00A0) instead
  -- nbsp = '\xc2\xa0',
  --

}
