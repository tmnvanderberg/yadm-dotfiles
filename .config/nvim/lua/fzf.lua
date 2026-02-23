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
    -- Restrict fzf matching to the content portion of rg output
    -- (<file>:<line>:<col>:<text>) so file names don't affect matches.
    fzf_opts = {
      ["--delimiter"] = ":",
      ["--nth"] = "4..",
    },
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

local function insert_block_at_position(bufnr, row, col, text, winid)
  local lines = vim.split(text or "", "\n", { plain = true })
  if #lines == 0 then
    lines = { "" }
  end

  vim.api.nvim_buf_set_text(bufnr, row, col, row, col, lines)

  if winid and vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
    local last_line = lines[#lines] or ""
    local new_row = row + #lines
    local new_col = (#lines == 1) and (col + #last_line) or #last_line
    vim.api.nvim_win_set_cursor(winid, { new_row, new_col })
  end
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

local function decode_list_output(output, extractor)
  local decoded = decode_json(output)
  if decoded then
    return extractor(decoded)
  end

  local pages = decode_json_pages(output)
  if not pages then
    return nil
  end

  local rows = {}
  local seen_ids = {}
  for _, page in ipairs(pages) do
    for _, row in ipairs(extractor(page)) do
      local id = type(row) == "table" and row.id or nil
      if id ~= nil then
        local id_key = tostring(id)
        if not seen_ids[id_key] then
          seen_ids[id_key] = true
          table.insert(rows, row)
        end
      else
        table.insert(rows, row)
      end
    end
  end

  return rows
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

local function extract_openai_output_text(decoded)
  if type(decoded) ~= "table" then
    return nil
  end

  if type(decoded.output_text) == "string" and decoded.output_text ~= "" then
    return decoded.output_text
  end
  if type(decoded.output_text) == "table" then
    local parts = {}
    for _, item in ipairs(decoded.output_text) do
      if type(item) == "string" and item ~= "" then
        table.insert(parts, item)
      end
    end
    if #parts > 0 then
      return table.concat(parts, "\n")
    end
  end

  local output = decoded.output
  if type(output) == "table" then
    local parts = {}
    for _, message in ipairs(output) do
      local content = type(message) == "table" and message.content or nil
      if type(content) == "table" then
        for _, chunk in ipairs(content) do
          if type(chunk) == "table" then
            local text_obj = chunk.text
            if type(text_obj) == "string" and text_obj ~= "" then
              table.insert(parts, text_obj)
            elseif type(text_obj) == "table" and type(text_obj.value) == "string" and text_obj.value ~= "" then
              table.insert(parts, text_obj.value)
            end
          end
        end
      end
    end
    if #parts > 0 then
      return table.concat(parts, "\n")
    end
  end

  local choices = decoded.choices
  if type(choices) == "table" and type(choices[1]) == "table" then
    local message = choices[1].message
    if type(message) == "table" then
      if type(message.content) == "string" and message.content ~= "" then
        return message.content
      end
      if type(message.content) == "table" then
        local parts = {}
        for _, chunk in ipairs(message.content) do
          if type(chunk) == "string" and chunk ~= "" then
            table.insert(parts, chunk)
          elseif type(chunk) == "table" then
            if type(chunk.text) == "string" and chunk.text ~= "" then
              table.insert(parts, chunk.text)
            elseif type(chunk.value) == "string" and chunk.value ~= "" then
              table.insert(parts, chunk.value)
            end
          end
        end
        if #parts > 0 then
          return table.concat(parts, "\n")
        end
      end
    end
  end

  return nil
end

local function extract_openai_error_message(decoded)
  if type(decoded) ~= "table" then
    return nil
  end
  if type(decoded.error) == "table" then
    local msg = decoded.error.message or decoded.error.error or decoded.error.type
    if type(msg) == "string" and msg ~= "" then
      return msg
    end
  end
  if type(decoded.message) == "string" and decoded.message ~= "" then
    return decoded.message
  end
  return nil
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

local function extract_story_points(item)
  item = extract_workitem_object(item) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  -- 1) Explicit/fallback custom field keys (instance-specific).
  local candidate_keys = {}
  local function add_candidate_key(k)
    if type(k) == "string" and k ~= "" then
      table.insert(candidate_keys, k)
    end
  end
  add_candidate_key(vim.g.jira_story_points_field) -- user override
  add_candidate_key("customfield_10057")           -- Story Points
  add_candidate_key("customfield_10016")           -- Story point estimate

  for _, k in ipairs(candidate_keys) do
    local t = value_to_text(fields[k])
    if t and t ~= "" then
      return t
    end
  end

  -- 2) Common direct aliases.
  local direct = find_field_value(item, {
    "Story Points",
    "story points",
    "Story point estimate",
    "story point estimate",
    "storypoints",
  }, true)
  local direct_text = value_to_text(direct)
  if direct_text and direct_text ~= "" then
    return direct_text
  end

  -- 3) Use names map when available (customfield_x -> display label).
  local names = type(item.names) == "table" and item.names or nil
  if names then
    for field_key, display_name in pairs(names) do
      local n = normalize_field_name(display_name)
      if n == "storypoints" or n == "storypointestimate" or n:find("storypoint", 1, true) then
        local t = value_to_text(fields[field_key])
        if t and t ~= "" then
          return t
        end
      end
    end
  end

  -- 4) Heuristic over field keys for non-standard payloads.
  for field_key, value in pairs(fields) do
    local k = normalize_field_name(field_key)
    if k == "storypoints" or k == "storypointestimate" or k:find("storypoint", 1, true) then
      local t = value_to_text(value)
      if t and t ~= "" then
        return t
      end
    end
  end

  return nil
end

local function extract_due_date(item)
  item = extract_workitem_object(item) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  -- 1) Optional explicit override for due-date custom field.
  local configured_key = vim.g.jira_due_date_field
  if type(configured_key) == "string" and configured_key ~= "" then
    local t = value_to_text(fields[configured_key])
    if t and t ~= "" then
      return t
    end
  end

  -- 2) Standard Jira due date fields.
  local direct = fields.duedate or fields.dueDate or fields["Due Date"] or fields["Due date"]
  local direct_text = value_to_text(direct)
  if direct_text and direct_text ~= "" then
    return direct_text
  end

  -- 3) Alias-based recursive match.
  local matched = find_field_value(item, {
    "due date",
    "duedate",
    "due_date",
    "target end",
  }, true)
  local matched_text = value_to_text(matched)
  if matched_text and matched_text ~= "" then
    return matched_text
  end

  -- 4) names map lookup for custom fields.
  local names = type(item.names) == "table" and item.names or nil
  if names then
    for field_key, display_name in pairs(names) do
      local n = normalize_field_name(display_name)
      if n == "duedate" or n:find("duedate", 1, true) or n == "targetend" then
        local t = value_to_text(fields[field_key])
        if t and t ~= "" then
          return t
        end
      end
    end
  end

  return nil
end

local function normalize_multiline_text(text, fallback)
  local normalized = value_to_text(text)
  if not normalized or normalized == "" then
    return fallback or "-"
  end
  normalized = normalized:gsub("\r\n", "\n"):gsub("\r", "\n")
  normalized = normalized:gsub("\n\n\n+", "\n\n")
  return normalized
end

local function extract_comment_list(comment_val)
  if type(comment_val) == "table" then
    return comment_val.comments or comment_val.values or (vim.tbl_islist(comment_val) and comment_val or nil)
  end
  if type(comment_val) == "string" and comment_val ~= "" then
    return { { body = comment_val } }
  end
  return nil
end

local function append_comment_discussion(lines, comment_val, heading)
  local comments = extract_comment_list(comment_val)
  table.insert(lines, "")
  table.insert(lines, heading or "### Comments & Discussion")

  if type(comments) ~= "table" or #comments == 0 then
    table.insert(lines, "- (no comments)")
    return
  end

  for idx, c in ipairs(comments) do
    local author = value_to_text(c.author) or value_to_text(c.updateAuthor) or "Unknown"
    local created = value_to_text(c.created) or ""
    local updated = value_to_text(c.updated) or ""
    local body = normalize_multiline_text(c.body, "-")

    table.insert(lines, string.format("#### %d. %s", idx, author))
    if created ~= "" then
      table.insert(lines, "- Posted: " .. created)
    end
    if updated ~= "" and updated ~= created then
      table.insert(lines, "- Updated: " .. updated)
    end
    table.insert(lines, "")
    for _, line in ipairs(vim.split(body, "\n", { plain = true })) do
      table.insert(lines, (line == "") and ">" or ("> " .. line))
    end
    if idx < #comments then
      table.insert(lines, "")
      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end
end

local function markdown_from_workitem(decoded, fallback_key, opts)
  opts = opts or {}
  local item = extract_workitem_object(decoded) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  local key = value_to_text(item.key) or value_to_text(fields.key) or fallback_key or "(unknown key)"
  local summary = value_to_text(item.summary) or value_to_text(fields.summary) or "(no summary)"

  local status_val = fields.status or find_field_value(item, { "status" }, false)
  local assignee_val = fields.assignee or find_field_value(item, { "assignee" }, false)
  local due_val = extract_due_date(item)
  local sp_val = extract_story_points(item)
  local dod_val = extract_definition_of_done(item)
  local desc_val = fields.description or find_field_value(item, { "description" }, false)
  local comment_val = fields.comment or find_field_value(item, { "comment" }, true)

  local status = value_to_text(status_val) or "-"
  local assignee = value_to_text(assignee_val) or "-"
  local due = value_to_text(due_val) or "-"
  local story_points = value_to_text(sp_val) or "-"
  local dod = normalize_multiline_text(dod_val, "-")
  local description = normalize_multiline_text(desc_val, "-")
  local title_level = tonumber(opts.title_level) or 2
  title_level = math.max(1, math.min(6, math.floor(title_level)))
  local ticket_title_prefix = string.rep("#", title_level)
  local section_prefix = string.rep("#", math.min(6, title_level + 1))

  local lines = {
    string.format("%s %s: %s", ticket_title_prefix, key, summary),
    "",
    string.format("- **Status:** %s", status),
    string.format("- **Assignee:** %s", assignee),
    string.format("- **Story Points:** %s", story_points),
    string.format("- **Due Date:** %s", due),
    "",
    section_prefix .. " Definition of Done (D.o.D)",
    dod,
    "",
    section_prefix .. " Description",
    description,
  }

  append_comment_discussion(lines, comment_val, section_prefix .. " Comments & Discussion")

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

      -- If key custom fields are unresolved, retry once with *all fields.
      local initial_dod = extract_definition_of_done(decoded)
      local initial_sp = extract_story_points(decoded)
      local initial_due = extract_due_date(decoded)
      if (not initial_dod or initial_dod == "")
        or (not initial_sp or initial_sp == "")
        or (not initial_due or initial_due == "") then
        spinner_start("Jira: loading all fields for missing custom fields ...")
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

local function trim_url_candidate(url)
  if type(url) ~= "string" then
    return nil
  end
  local out = vim.trim(url)
  if out == "" then
    return nil
  end

  out = out:gsub("[,.;:!?]+$", "")

  local function count_chars(s, ch)
    local _, n = s:gsub(vim.pesc(ch), "")
    return n
  end

  while out:sub(-1) == ")" and count_chars(out, "(") < count_chars(out, ")") do
    out = out:sub(1, -2)
  end
  while out:sub(-1) == "]" and count_chars(out, "[") < count_chars(out, "]") do
    out = out:sub(1, -2)
  end
  while out:sub(-1) == "}" and count_chars(out, "{") < count_chars(out, "}") do
    out = out:sub(1, -2)
  end

  if out:match("^https?://") then
    return out
  end
  return nil
end

local function find_url_under_cursor(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row = cursor[1] - 1
  local col = cursor[2] + 1
  local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), row, row + 1, false)[1] or ""

  local idx = 1
  while true do
    local s, e = line:find("https?://[%w%-._~:/%?#%[%]@!$&'*+,;=%%()]+", idx)
    if not s then
      break
    end
    if col >= s and col <= e then
      local candidate = trim_url_candidate(line:sub(s, e))
      if candidate then
        return candidate
      end
    end
    idx = e + 1
  end

  idx = 1
  while true do
    local s, e, link = line:find("%[[^%]]-%]%((https?://[^)%s]+)%)", idx)
    if not s then
      break
    end
    if col >= s and col <= e then
      local candidate = trim_url_candidate(link)
      if candidate then
        return candidate
      end
    end
    idx = e + 1
  end

  local cfile = trim_url_candidate(vim.fn.expand("<cfile>"))
  if cfile then
    return cfile
  end

  return nil
end

local function open_url_from_window_cursor(win)
  local url = find_url_under_cursor(win)
  if not url then
    vim.notify("No URL found under cursor", vim.log.levels.WARN)
    return
  end

  if vim.ui and type(vim.ui.open) == "function" then
    vim.ui.open(url)
    return
  end

  local openers = {
    { "open", url },               -- macOS
    { "xdg-open", url },           -- Linux
    { "cmd", "/c", "start", url }, -- Windows
  }

  local function try_idx(i)
    if i > #openers then
      vim.notify("Could not open URL: " .. url, vim.log.levels.ERROR)
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

local function open_markdown_preview_window(title, markdown)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(markdown, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false

  local use_float = vim.g.jira_preview_use_float == true
  local win = nil

  if use_float then
    local width = math.max(80, math.floor(vim.o.columns * 0.72))
    local height = math.max(20, math.floor(vim.o.lines * 0.78))
    local row = math.floor((vim.o.lines - height) / 2 - 1)
    local col = math.floor((vim.o.columns - width) / 2)

    win = vim.api.nvim_open_win(buf, true, {
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
  else
    vim.cmd("tabnew")
    win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    pcall(vim.api.nvim_buf_set_name, buf, "jira-preview://" .. tostring(title))
  end

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].cursorline = true

  local function close_preview()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  vim.keymap.set("n", "q", close_preview, { buffer = buf, silent = true, desc = "Close preview" })
  vim.keymap.set("n", "<Esc>", close_preview, { buffer = buf, silent = true, desc = "Close preview" })
  vim.keymap.set("n", "gx", function()
    open_url_from_window_cursor(win)
  end, { buffer = buf, silent = true, desc = "Open URL under cursor" })
  vim.keymap.set("n", "<CR>", function()
    open_url_from_window_cursor(win)
  end, { buffer = buf, silent = true, desc = "Open URL under cursor" })
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

      local initial_dod = extract_definition_of_done(decoded)
      local initial_sp = extract_story_points(decoded)
      local initial_due = extract_due_date(decoded)
      if (not initial_dod or initial_dod == "")
        or (not initial_sp or initial_sp == "")
        or (not initial_due or initial_due == "") then
        spinner_start("Jira: loading all fields for missing custom fields ...")
        run_cmd_async(
          { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
          function(all_output, all_code)
            spinner_stop()
            if all_code == 0 then
              local all_decoded = decode_json(all_output)
              if all_decoded then
                open_markdown_preview_window("Jira Preview: " .. key, markdown_from_workitem(all_decoded, key))
                return
              end
            end
            open_markdown_preview_window("Jira Preview: " .. key, markdown_from_workitem(decoded, key))
          end
        )
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

local function summarize_jira_ticket_progress_with_openai(key)
  local api_key = vim.env.OPENAI_API_KEY
  if type(api_key) ~= "string" or api_key == "" then
    vim.notify("OPENAI_API_KEY is not set", vim.log.levels.ERROR)
    return
  end

  spinner_start("Jira: loading " .. key .. " ...")
  run_cmd_async(
    { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
    function(ticket_output, ticket_code)
      if ticket_code ~= 0 then
        spinner_stop()
        vim.notify("Failed to fetch Jira work item " .. key .. ":\n" .. ticket_output, vim.log.levels.ERROR)
        return
      end

      local prompt = table.concat({
        "Summarize progress for Jira ticket " .. key .. ".",
        "Use the raw JSON exactly as provided below.",
        "Output compact markdown that is easy to scan.",
        "Required format:",
        "## " .. key .. " Progress Summary",
        "- Snapshot: 1-2 bullets",
        "- Progress Signals: 2-5 bullets",
        "- Risks / Unknowns: 1-4 bullets",
        "- Next Checkpoints: 1-3 bullets",
        "### Discussion (Markdown)",
        "- Render 3-8 bullets from comments/history as markdown-friendly lines.",
        "- Include speaker + date when available.",
        "- Preserve technical details and decisions, but clean noisy formatting.",
        "### Discussion (Plain Text)",
        "- Provide a plain-text digest of the same discussion.",
        "- Use one line per item: [date] author: message",
        "- Keep each line concise and readable in monospaced editors.",
        "Focus on current status and concrete progress evidence from the ticket history/comments/fields.",
        "",
        "RAW_JIRA_JSON_START",
        ticket_output,
        "RAW_JIRA_JSON_END",
      }, "\n")

      local req = {
        model = vim.g.openai_model or "gpt-4.1-mini",
        temperature = 0.2,
        max_output_tokens = 750,
        input = {
          {
            role = "system",
            content = "You are a concise engineering delivery analyst. Prefer concrete facts over speculation.",
          },
          {
            role = "user",
            content = prompt,
          },
        },
      }

      local req_json = encode_json(req)
      if req_json == "<json encode failed>" then
        spinner_stop()
        vim.notify("Failed to encode OpenAI request JSON", vim.log.levels.ERROR)
        return
      end

      local req_path = vim.fn.tempname() .. "_openai_req.json"
      local write_ok = pcall(vim.fn.writefile, { req_json }, req_path)
      if not write_ok then
        spinner_stop()
        vim.notify("Failed to write temporary OpenAI request file", vim.log.levels.ERROR)
        return
      end

      spinner_start("OpenAI: summarizing " .. key .. " ...")
      run_cmd_async(
        {
          "curl",
          "-sS",
          "-X", "POST",
          "https://api.openai.com/v1/responses",
          "-H", "Authorization: Bearer " .. api_key,
          "-H", "Content-Type: application/json",
          "--data-binary", "@" .. req_path,
        },
        function(openai_output, openai_code)
          pcall(vim.fn.delete, req_path)
          spinner_stop()

          if openai_code ~= 0 then
            vim.notify("OpenAI request failed:\n" .. openai_output, vim.log.levels.ERROR)
            return
          end

          local decoded = decode_json(openai_output)
          if not decoded then
            vim.notify("Could not parse OpenAI response JSON", vim.log.levels.ERROR)
            return
          end

          local api_err = extract_openai_error_message(decoded)
          if api_err then
            vim.notify("OpenAI API error: " .. api_err, vim.log.levels.ERROR)
            return
          end

          local summary = extract_openai_output_text(decoded)
          if not summary or summary == "" then
            jira_debug_log(
              "jira_summarize_ticket_progress:openai-response-missing-text",
              { "curl", "https://api.openai.com/v1/responses" },
              openai_output
            )
            vim.notify("OpenAI response had no readable text. Raw response saved to debug log.", vim.log.levels.ERROR)
            return
          end

          local ticket_decoded = decode_json(ticket_output)
          local combined_markdown = summary
          if ticket_decoded then
            combined_markdown = table.concat({
              summary,
              "",
              "---",
              "",
              "## Full Ticket Preview",
              "",
              markdown_from_workitem(ticket_decoded, key, { title_level = 3 }),
            }, "\n")
          else
            combined_markdown = table.concat({
              summary,
              "",
              "---",
              "",
              "## Full Ticket Preview",
              "",
              "_Could not parse Jira JSON for preview section._",
            }, "\n")
          end

          open_markdown_preview_window("Jira Progress Summary: " .. key, combined_markdown)
        end
      )
    end
  )
end

local function jira_summarize_ticket_progress(opts)
  resolve_ticket_key(opts, function(key)
    summarize_jira_ticket_progress_with_openai(key)
  end)
end

local function openai_current_buffer_prompt(opts)
  opts = opts or {}
  local query = opts.query or opts.args

  local function run_for_query(input_query)
    local cleaned_query = vim.trim(input_query or "")
    if cleaned_query == "" then
      return
    end

    local api_key = vim.env.OPENAI_API_KEY
    if type(api_key) ~= "string" or api_key == "" then
      vim.notify("OPENAI_API_KEY is not set", vim.log.levels.ERROR)
      return
    end

    local bufnr = vim.api.nvim_get_current_buf()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      vim.notify("Current buffer is not valid", vim.log.levels.ERROR)
      return
    end

    local winid = vim.api.nvim_get_current_win()
    local row, col = unpack(vim.api.nvim_win_get_cursor(winid))
    row = row - 1

    local buffer_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local buffer_text = table.concat(buffer_lines, "\n")
    if vim.trim(buffer_text) == "" then
      vim.notify("Current buffer is empty", vim.log.levels.WARN)
      return
    end

    local prompt = table.concat({
      "Use the buffer content as context and respond to the user query.",
      "Keep the answer focused and directly usable in an editor.",
      "",
      "User query:",
      cleaned_query,
      "",
      "BUFFER_CONTEXT_START",
      buffer_text,
      "BUFFER_CONTEXT_END",
    }, "\n")

    local req = {
      model = vim.g.openai_model or "gpt-4.1-mini",
      temperature = 0.2,
      max_output_tokens = 1000,
      input = {
        {
          role = "system",
          content = "You are a concise coding assistant. Provide practical output for direct insertion into a text buffer.",
        },
        {
          role = "user",
          content = prompt,
        },
      },
    }

    local req_json = encode_json(req)
    if req_json == "<json encode failed>" then
      vim.notify("Failed to encode OpenAI request JSON", vim.log.levels.ERROR)
      return
    end

    local req_path = vim.fn.tempname() .. "_openai_req.json"
    local write_ok = pcall(vim.fn.writefile, { req_json }, req_path)
    if not write_ok then
      vim.notify("Failed to write temporary OpenAI request file", vim.log.levels.ERROR)
      return
    end

    spinner_start("OpenAI: generating from current buffer ...")
    run_cmd_async(
      {
        "curl",
        "-sS",
        "-X", "POST",
        "https://api.openai.com/v1/responses",
        "-H", "Authorization: Bearer " .. api_key,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" .. req_path,
      },
      function(openai_output, openai_code)
        pcall(vim.fn.delete, req_path)
        spinner_stop()

        if openai_code ~= 0 then
          vim.notify("OpenAI request failed:\n" .. openai_output, vim.log.levels.ERROR)
          return
        end

        local decoded = decode_json(openai_output)
        if not decoded then
          vim.notify("Could not parse OpenAI response JSON", vim.log.levels.ERROR)
          return
        end

        local api_err = extract_openai_error_message(decoded)
        if api_err then
          vim.notify("OpenAI API error: " .. api_err, vim.log.levels.ERROR)
          return
        end

        local output_text = extract_openai_output_text(decoded)
        if not output_text or output_text == "" then
          vim.notify("OpenAI response had no readable text", vim.log.levels.ERROR)
          return
        end

        if not vim.api.nvim_buf_is_valid(bufnr) then
          vim.notify("Target buffer was closed before output could be inserted", vim.log.levels.WARN)
          return
        end

        insert_block_at_position(bufnr, row, col, output_text, winid)
      end
    )
  end

  if type(query) == "string" and vim.trim(query) ~= "" then
    run_for_query(query)
    return
  end

  vim.ui.input({ prompt = "OpenAI Query> " }, function(input)
    if input == nil then
      return
    end
    run_for_query(input)
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

local function read_global_or_env(global_name, env_name, default_value)
  local gval = vim.g[global_name]
  if type(gval) == "string" then
    gval = vim.trim(gval)
    if gval ~= "" then
      return gval
    end
  end

  local eval = vim.env[env_name]
  if type(eval) == "string" then
    eval = vim.trim(eval)
    if eval ~= "" then
      return eval
    end
  end

  return default_value
end

local function normalize_afas_auth_value(token)
  token = vim.trim(token or "")
  if token == "" then
    return ""
  end
  if token:match("^[Aa]fas[Tt]oken%s+") or token:match("^[Bb]earer%s+") then
    return token
  end
  return "AfasToken " .. token
end

local function build_afas_projects_url()
  local explicit_url = read_global_or_env("afas_profit_projects_url", "AFAS_PROFIT_PROJECTS_URL", nil)
  if type(explicit_url) == "string" and explicit_url ~= "" then
    return explicit_url
  end

  local base_url = read_global_or_env("afas_profit_base_url", "AFAS_PROFIT_BASE_URL", nil)
  if type(base_url) ~= "string" or base_url == "" then
    return nil
  end

  local connector = read_global_or_env("afas_profit_projects_connector", "AFAS_PROFIT_PROJECTS_CONNECTOR", "Projects")
  base_url = base_url:gsub("/+$", "")
  if base_url:match("/profitrestservices$") then
    return string.format("%s/connectors/%s", base_url, connector)
  end
  return string.format("%s/profitrestservices/connectors/%s", base_url, connector)
end

local function extract_afas_rows(decoded)
  if type(decoded) ~= "table" then
    return {}
  end

  if vim.tbl_islist(decoded) then
    return decoded
  end

  for _, key in ipairs({ "rows", "items", "results", "values", "value", "data", "projects" }) do
    if vim.tbl_islist(decoded[key]) then
      return decoded[key]
    end
  end

  if type(decoded.d) == "table" then
    return extract_afas_rows(decoded.d)
  end

  return {}
end

local function find_string_field_by_name(tbl, wanted)
  for k, v in pairs(tbl) do
    if type(k) == "string" and type(v) == "string" and string.lower(k) == wanted then
      local text = vim.trim(v)
      if text ~= "" then
        return text
      end
    end
  end
  return nil
end

local function extract_afas_project_name(item)
  if type(item) == "string" then
    local text = vim.trim(item)
    return text ~= "" and text or nil
  end
  if type(item) ~= "table" then
    return nil
  end

  for _, key in ipairs({
    "name",
    "naam",
    "projectname",
    "projectnaam",
    "displayname",
    "omschrijving",
    "description",
    "project",
  }) do
    local value = find_string_field_by_name(item, key)
    if value then
      return value
    end
  end

  for k, v in pairs(item) do
    if type(k) == "string" and type(v) == "string" then
      local key_l = string.lower(k)
      if key_l:find("name", 1, true) or key_l:find("naam", 1, true) then
        local text = vim.trim(v)
        if text ~= "" then
          return text
        end
      end
    end
  end

  for _, v in pairs(item) do
    if type(v) == "string" then
      local text = vim.trim(v)
      if text ~= "" then
        return text
      end
    end
  end

  return nil
end

local function afas_projects(opts)
  opts = opts or {}

  local projects_url = build_afas_projects_url()
  local token_raw = read_global_or_env("afas_profit_token", "AFAS_PROFIT_TOKEN", nil)
  local auth_header = normalize_afas_auth_value(token_raw or "")

  if type(projects_url) ~= "string" or projects_url == "" then
    vim.notify(
      "AFAS config missing. Set vim.g.afas_profit_projects_url or vim.g.afas_profit_base_url (+ optional connector).",
      vim.log.levels.ERROR
    )
    return
  end
  if auth_header == "" then
    vim.notify("AFAS token missing. Set vim.g.afas_profit_token or AFAS_PROFIT_TOKEN.", vim.log.levels.ERROR)
    return
  end

  spinner_start("AFAS: loading projects ...")
  run_cmd_async({
    "curl",
    "-sS",
    "--fail-with-body",
    "-H", "Accept: application/json",
    "-H", "Authorization: " .. auth_header,
    projects_url,
  }, function(output, code)
    spinner_stop()
    if code ~= 0 then
      vim.notify("AFAS projects request failed:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      vim.notify("Could not parse AFAS projects JSON output", vim.log.levels.ERROR)
      return
    end

    local names = {}
    local seen = {}
    for _, row in ipairs(extract_afas_rows(decoded)) do
      local name = extract_afas_project_name(row)
      if name and not seen[name] then
        seen[name] = true
        table.insert(names, name)
      end
    end

    table.sort(names, function(a, b)
      return string.lower(a) < string.lower(b)
    end)

    if #names == 0 then
      vim.notify("No AFAS projects found in API response", vim.log.levels.INFO)
      return
    end

    fzf.fzf_exec(names, {
      prompt = "AFAS Projects> ",
      query = opts.query,
      previewer = false,
      actions = {
        ['default'] = function(selected)
          local project_name = selected and selected[1]
          if project_name and project_name ~= "" then
            insert_text_at_cursor(project_name)
          end
        end,
      },
    })
  end)
end

local function extract_status_assignee_parent(item)
  item = extract_workitem_object(item) or {}
  local fields = type(item.fields) == "table" and item.fields or {}
  local status_val = fields.status or find_field_value(item, { "status" }, false)
  local assignee_val = fields.assignee or find_field_value(item, { "assignee" }, false)
  local status = value_to_text(status_val) or "-"
  local assignee = value_to_text(assignee_val) or "-"

  local function resolve_parent_candidate(parent_val)
    local out_key = nil
    local out_name = nil
    if type(parent_val) == "table" then
      out_key = value_to_text(parent_val.key) or value_to_text(parent_val.issueKey) or value_to_text(parent_val.id)
      out_name = value_to_text(parent_val.summary) or value_to_text(parent_val.name) or value_to_text(parent_val.title)
      if type(parent_val.fields) == "table" then
        out_key = out_key
          or value_to_text(parent_val.fields.key)
          or value_to_text(parent_val.fields.issueKey)
          or value_to_text(parent_val.fields.id)
        out_name = out_name
          or value_to_text(parent_val.fields.summary)
          or value_to_text(parent_val.fields.name)
          or value_to_text(parent_val.fields.title)
      end
      return out_key, out_name
    end

    local txt = value_to_text(parent_val)
    if txt and txt ~= "" then
      out_name = txt
      if txt:match("^[A-Z][A-Z0-9_]+%-%d+$") then
        out_key = txt
      end
    end
    return out_key, out_name
  end

  local parent_key = nil
  local parent_name = nil
  local parent_candidates = {
    fields.parent,
    item.parent,
    fields.customfield_10014, -- common Epic Link field in classic projects
    fields.customfield_10018, -- alt epic relation field in some Jira setups
    fields["Epic Link"],
    fields["parent epic"],
    fields.epic,
    find_field_value(item, { "parent" }, false),
    find_field_value(item, { "epic link", "epiclink", "parent epic", "epic" }, true),
  }

  local names = type(item.names) == "table" and item.names or nil
  if names then
    for field_key, display_name in pairs(names) do
      local n = normalize_field_name(display_name)
      if n == "epiclink"
        or n == "parentepic"
        or n == "epic"
        or n:find("epiclink", 1, true)
        or n:find("parentepic", 1, true) then
        table.insert(parent_candidates, fields[field_key])
      end
    end
  end

  for _, candidate in ipairs(parent_candidates) do
    local key, name = resolve_parent_candidate(candidate)
    if (key and key ~= "") or (name and name ~= "") then
      parent_key = parent_key or key
      parent_name = parent_name or name
      if parent_key and parent_key ~= "" then
        break
      end
    end
  end

  local function add_sprint_name(names, seen, raw_name)
    local name = clean_jira_text(raw_name or "")
    if name ~= "" and not seen[name] then
      seen[name] = true
      table.insert(names, name)
    end
  end

  local function collect_sprint_names(value, names, seen, visited, depth)
    depth = depth or 0
    if depth > 6 or value == nil then
      return
    end

    if type(value) == "string" then
      local direct = value_to_text(value)
      if direct and direct ~= "" then
        local from_legacy = direct:match("name=([^,%]]+)")
        add_sprint_name(names, seen, from_legacy or direct)
      end
      return
    end

    if type(value) ~= "table" then
      return
    end

    if visited[value] then
      return
    end
    visited[value] = true

    if vim.tbl_islist(value) then
      for _, item_val in ipairs(value) do
        collect_sprint_names(item_val, names, seen, visited, depth + 1)
      end
      return
    end

    add_sprint_name(names, seen, value_to_text(value.name))
    add_sprint_name(names, seen, value_to_text(value.displayName))

    local list_keys = { "sprint", "sprints", "values", "items", "results", "data" }
    for _, k in ipairs(list_keys) do
      if value[k] ~= nil then
        collect_sprint_names(value[k], names, seen, visited, depth + 1)
      end
    end
  end

  local sprint_names = {}
  local sprint_seen = {}
  local sprint_visited = {}
  local sprint_candidates = {
    fields.sprint,
    fields.Sprint,
    fields.customfield_10020, -- common Jira Software sprint field
    find_field_value(item, { "sprint" }, true),
  }
  local names = type(item.names) == "table" and item.names or nil
  if names then
    for field_key, display_name in pairs(names) do
      local n = normalize_field_name(display_name)
      if n == "sprint" or n:find("sprint", 1, true) then
        table.insert(sprint_candidates, fields[field_key])
      end
    end
  end
  if type(vim.g.jira_sprint_field) == "string" and vim.g.jira_sprint_field ~= "" then
    table.insert(sprint_candidates, 1, fields[vim.g.jira_sprint_field])
  end
  for _, candidate in ipairs(sprint_candidates) do
    collect_sprint_names(candidate, sprint_names, sprint_seen, sprint_visited, 0)
  end
  local sprint = (#sprint_names > 0) and table.concat(sprint_names, " | ") or "-"

  return status, assignee, parent_key, parent_name, sprint
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

local function markdown_escape_inline(text)
  local s = tostring(text or "")
  -- Escape markdown punctuation that can alter inline rendering.
  s = s:gsub("\\", "\\\\")
  s = s:gsub("([%[%]%(%)`*_~<>])", "\\%1")
  return s
end

local function build_epics_stories_report(project_key, project_name, epics, stories, exclude_done)
  local function normalize_match(text)
    text = clean_jira_text(text or ""):lower()
    text = text:gsub("[%p]", " ")
    text = text:gsub("%s+", " ")
    return vim.trim(text)
  end

  local function fixed_width(text, width)
    local s = clean_jira_text(text or "-")
    local function display_width(v)
      return vim.fn.strdisplaywidth(v)
    end

    local function truncate_display(v, max_width)
      if display_width(v) <= max_width then
        return v
      end
      local suffix = (max_width > 3) and "..." or ""
      local suffix_w = display_width(suffix)
      local target = math.max(0, max_width - suffix_w)
      local out = ""
      for _, ch in ipairs(vim.fn.split(v, "\\zs")) do
        local candidate = out .. ch
        if display_width(candidate) > target then
          break
        end
        out = candidate
      end
      return out .. suffix
    end

    s = truncate_display(s, width)
    local pad = width - display_width(s)
    if pad > 0 then
      s = s .. string.rep(" ", pad)
    end
    return s
  end

  local type_w = 8
  local key_w = 14
  local status_w = 16
  local assignee_w = 18
  local sprint_w = 22
  local title_w = 44

  local function format_row(kind, key, status, assignee, sprint, title)
    return table.concat({
      fixed_width(kind, type_w),
      fixed_width(key, key_w),
      fixed_width(status, status_w),
      fixed_width(assignee, assignee_w),
      fixed_width(sprint, sprint_w),
      fixed_width(title, title_w),
    }, "  ")
  end

  local lines = {}
  table.insert(lines, string.format("Project: %s [%s]", clean_jira_text(project_name), clean_jira_text(project_key)))
  table.insert(lines, string.format("Scope: %s", exclude_done and "excluding Done issues" or "including Done issues"))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")
  table.insert(lines, "Epics & Stories:")
  local header = format_row("TYPE", "KEY", "STATUS", "ASSIGNEE", "SPRINT", "TITLE")
  table.insert(lines, header)
  table.insert(lines, string.rep("-", #header))

  if #epics == 0 then
    table.insert(lines, "(none)")
    return table.concat(lines, "\n")
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

  local first_epic = true
  for _, epic_key in ipairs(epic_keys) do
    if not first_epic then
      table.insert(lines, "")
    end
    first_epic = false

    local epic = epic_by_key[epic_key]
    table.insert(lines, format_row("EPIC", epic.key, epic.status, epic.assignee, epic.sprint, epic.summary))
    local bucket = stories_by_epic[epic_key] or {}
    if #bucket == 0 then
      table.insert(lines, format_row("  STORY", "-", "-", "-", "-", "|- (no stories)"))
    else
      table.sort(bucket, function(a, b) return a.key < b.key end)
      for _, story in ipairs(bucket) do
        table.insert(lines, format_row("  STORY", story.key, story.status, story.assignee, story.sprint, "|- " .. story.summary))
      end
    end
  end

  table.insert(lines, "")
  table.insert(lines, "Unparented Stories")
  table.insert(lines, string.rep("-", #header))
  if #unparented_stories == 0 then
    table.insert(lines, "(none)")
  else
    table.sort(unparented_stories, function(a, b) return a.key < b.key end)
    for _, story in ipairs(unparented_stories) do
      table.insert(lines, format_row("STORY", story.key, story.status, story.assignee, story.sprint, story.summary))
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
    local function split_field_list(field_list)
      local out = {}
      for field in tostring(field_list or ""):gmatch("[^,]+") do
        local f = vim.trim(field)
        if f ~= "" then
          table.insert(out, f)
        end
      end
      return out
    end

    local function join_filtered_fields(field_list, disallowed_set)
      local cleaned = {}
      local seen = {}
      for _, f in ipairs(split_field_list(field_list)) do
        local fl = string.lower(f)
        if not disallowed_set[fl] and not seen[fl] then
          seen[fl] = true
          table.insert(cleaned, f)
        end
      end
      if #cleaned == 0 then
        return "key,summary,status,assignee"
      end
      return table.concat(cleaned, ",")
    end

    local function extract_disallowed_fields_from_error(err)
      local disallowed = {}
      local text = tostring(err or "")
      for quoted in text:gmatch("'([^']+)'") do
        for token in quoted:gmatch("[^,]+") do
          local f = vim.trim(token):lower()
          if f ~= "" and f ~= "field" and f ~= "fields" then
            disallowed[f] = true
          end
        end
      end
      return disallowed
    end

    local function run_search_with_fields(request_fields, allow_retry)
      run_cmd_async(
        { "acli", "jira", "workitem", "search", "--jql", jql, "--fields", request_fields, "--paginate", "--json" },
        function(output, code)
          if code ~= 0 then
            if allow_retry and tostring(output or ""):lower():find("not allowed", 1, true) then
              local disallowed = extract_disallowed_fields_from_error(output)
              local fallback_fields = join_filtered_fields(request_fields, disallowed)
              if fallback_fields ~= request_fields then
                run_search_with_fields(fallback_fields, false)
                return
              end
            end
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

    run_search_with_fields(fields, true)
  end

  local done_filter = exclude_done and " AND statusCategory != Done" or ""

  local function enrich_rows_with_sprint(rows, done)
    local missing = {}
    local needed_by_key = {}
    for _, row in ipairs(rows or {}) do
      if row.key and row.key ~= "" and (not row.sprint or row.sprint == "" or row.sprint == "-") then
        table.insert(missing, row)
        needed_by_key[row.key] = true
      end
    end
    if #missing == 0 then
      done()
      return
    end

    local sprint_names_by_key = {}
    local function add_sprint_for_key(key, sprint_name)
      local k = clean_jira_text(key)
      local s = clean_jira_text(sprint_name)
      if k == "" or s == "" or not needed_by_key[k] then
        return
      end
      sprint_names_by_key[k] = sprint_names_by_key[k] or {}
      sprint_names_by_key[k][s] = true
    end

    local function extract_rows_from_decoded(decoded, keys)
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

    local function decode_rows_with_keys(output, keys)
      local decoded = decode_json(output)
      if decoded then
        return extract_rows_from_decoded(decoded, keys)
      end

      local pages = decode_json_pages(output)
      if not pages then
        return nil
      end

      local rows = {}
      local seen_ids = {}
      for _, page in ipairs(pages) do
        for _, row in ipairs(extract_rows_from_decoded(page, keys)) do
          local id = type(row) == "table" and row.id or nil
          if id ~= nil then
            local id_key = tostring(id)
            if not seen_ids[id_key] then
              seen_ids[id_key] = true
              table.insert(rows, row)
            end
          else
            table.insert(rows, row)
          end
        end
      end
      return rows
    end

    local function extract_board_id_name_local(board)
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

    local function extract_board_project_key_local(board)
      if type(board) ~= "table" then
        return "-"
      end
      local location = type(board.location) == "table" and board.location or {}
      local project = type(board.project) == "table" and board.project or {}
      local key = value_to_text(board.projectKey)
        or value_to_text(location.projectKey)
        or value_to_text(project.key)
        or "-"
      return clean_jira_text(key)
    end

    local function extract_sprint_info_local(sprint)
      if type(sprint) ~= "table" then
        return nil
      end
      local id = sprint.id
      if type(id) ~= "number" and type(id) ~= "string" then
        return nil
      end
      local name = value_to_text(sprint.name) or tostring(id)
      return {
        id = tonumber(id) or id,
        name = clean_jira_text(name),
      }
    end

    local function collect_boards_from_rows(board_rows)
      local boards = {}
      local seen_board = {}
      for _, board in ipairs(board_rows or {}) do
        local board_id, board_name = extract_board_id_name_local(board)
        if board_id then
          local key = tostring(board_id)
          if not seen_board[key] then
            seen_board[key] = true
            table.insert(boards, { id = board_id, name = board_name or key })
          end
        end
      end
      return boards
    end

    local function continue_with_boards(boards)
      if #boards == 0 then
        done()
        return
      end

      local board_sprints = {}
      local seen_board_sprint = {}
      local board_next = 1
      local board_active = 0
      local board_concurrency = 3

      local function finish_and_apply()
        for _, row in ipairs(missing) do
          local set = sprint_names_by_key[row.key]
          if set then
            local names = {}
            for sprint_name, _ in pairs(set) do
              table.insert(names, sprint_name)
            end
            table.sort(names)
            row.sprint = table.concat(names, " | ")
          end
        end
        done()
      end

      local function load_sprints_for_board(board, on_done_board)
        local sprint_list_cmd = {
          "acli", "jira", "board", "list-sprints",
          "--id", tostring(board.id),
          "--state", "active,future,closed",
          "--paginate",
          "--json",
        }
        run_cmd_async(sprint_list_cmd, function(sprint_output, sprint_code)
          if sprint_code == 0 then
            local sprint_rows = decode_rows_with_keys(sprint_output, { "sprints", "values", "results", "items", "data" })
            if sprint_rows then
              for _, raw in ipairs(sprint_rows) do
                local sprint = extract_sprint_info_local(raw)
                if sprint then
                  local skey = tostring(board.id) .. ":" .. tostring(sprint.id)
                  if not seen_board_sprint[skey] then
                    seen_board_sprint[skey] = true
                    table.insert(board_sprints, {
                      board_id = board.id,
                      sprint_id = sprint.id,
                      sprint_name = sprint.name,
                    })
                  end
                end
              end
            end
          end
          on_done_board()
        end)
      end

      local function pump_boards()
        while board_active < board_concurrency and board_next <= #boards do
          local board = boards[board_next]
          board_next = board_next + 1
          board_active = board_active + 1
          load_sprints_for_board(board, function()
            board_active = board_active - 1
            if board_next > #boards and board_active == 0 then
              if #board_sprints == 0 then
                finish_and_apply()
                return
              end

              local sprint_next = 1
              local sprint_active = 0
              local sprint_concurrency = tonumber(vim.g.jira_epics_stories_sprint_map_concurrency) or 8
              if sprint_concurrency < 1 then
                sprint_concurrency = 1
              end

              local function pump_sprints()
                while sprint_active < sprint_concurrency and sprint_next <= #board_sprints do
                  local item = board_sprints[sprint_next]
                  sprint_next = sprint_next + 1
                  sprint_active = sprint_active + 1

                  local sprint_issue_cmd = {
                    "acli", "jira", "sprint", "list-workitems",
                    "--board", tostring(item.board_id),
                    "--sprint", tostring(item.sprint_id),
                    "--fields", "key",
                    "--paginate",
                    "--json",
                  }
                  run_cmd_async(sprint_issue_cmd, function(issue_output, issue_code)
                    if issue_code == 0 then
                      local issue_rows = decode_list_output(issue_output, extract_workitems)
                      if issue_rows then
                        for _, issue in ipairs(issue_rows) do
                          local key = value_to_text(issue.key)
                            or value_to_text(type(issue.fields) == "table" and issue.fields.key or nil)
                            or value_to_text(issue.id)
                          if key then
                            add_sprint_for_key(key, item.sprint_name)
                          end
                        end
                      end
                    end

                    sprint_active = sprint_active - 1
                    if sprint_next > #board_sprints and sprint_active == 0 then
                      finish_and_apply()
                      return
                    end
                    pump_sprints()
                  end)
                end
              end

              pump_sprints()
              return
            end
            pump_boards()
          end)
        end
      end

      pump_boards()
    end

    local board_search_cmd = { "acli", "jira", "board", "search", "--project", project_key, "--type", "scrum", "--paginate", "--json" }
    run_cmd_async(board_search_cmd, function(board_output, board_code)
      local board_rows = (board_code == 0) and decode_rows_with_keys(board_output, { "boards", "values", "results", "items", "data" }) or nil
      local boards = collect_boards_from_rows(board_rows)
      if #boards > 0 then
        continue_with_boards(boards)
        return
      end

      local board_search_all_cmd = { "acli", "jira", "board", "search", "--type", "scrum", "--paginate", "--json" }
      run_cmd_async(board_search_all_cmd, function(all_output, all_code)
        if all_code ~= 0 then
          done()
          return
        end
        local all_rows = decode_rows_with_keys(all_output, { "boards", "values", "results", "items", "data" })
        if not all_rows then
          done()
          return
        end
        local filtered = {}
        local project_key_norm = string.lower(clean_jira_text(project_key))
        for _, board in ipairs(all_rows) do
          local bkey = extract_board_project_key_local(board)
          if string.lower(clean_jira_text(bkey)) == project_key_norm then
            table.insert(filtered, board)
          end
        end
        continue_with_boards(collect_boards_from_rows(filtered))
      end)
    end)
  end

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
        local status, assignee, _, _, sprint = extract_status_assignee_parent(item)
        table.insert(epics, {
          key = clean_jira_text(key),
          summary = clean_jira_text(summary),
          status = clean_jira_text(status),
          assignee = clean_jira_text(assignee),
          sprint = clean_jira_text(sprint),
        })
      end
    end

    local stories_by_key = {}
    local function upsert_story(item, forced_parent_key)
      local key, summary = extract_key_summary(item)
      if not key then
        return
      end
      local status, assignee, _, _, sprint = extract_status_assignee_parent(item)
      local clean_key = clean_jira_text(key)
      local existing = stories_by_key[clean_key]
      if not existing then
        existing = {
          key = clean_key,
          summary = clean_jira_text(summary),
          status = clean_jira_text(status),
          assignee = clean_jira_text(assignee),
          sprint = clean_jira_text(sprint),
          parent_key = forced_parent_key and clean_jira_text(forced_parent_key) or nil,
        }
        stories_by_key[clean_key] = existing
      elseif (not existing.parent_key or existing.parent_key == "") and forced_parent_key then
        existing.parent_key = clean_jira_text(forced_parent_key)
      end
      if (not existing.sprint or existing.sprint == "-" or existing.sprint == "") and sprint and sprint ~= "" then
        existing.sprint = clean_jira_text(sprint)
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

          local sprint_rows = {}
          for _, epic in ipairs(epics) do
            table.insert(sprint_rows, epic)
          end
          for _, story in ipairs(stories) do
            table.insert(sprint_rows, story)
          end

          spinner_start("Jira: loading sprint assignments ...")
          enrich_rows_with_sprint(sprint_rows, function()
            spinner_stop()
            insert_block_at_cursor(build_epics_stories_report(project_key, project_name, epics, stories, exclude_done))
          end)
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
  local exclude_done = opts.exclude_done == true
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

local function extract_board_project_key_name(board)
  if type(board) ~= "table" then
    return "-", "-"
  end

  local location = type(board.location) == "table" and board.location or {}
  local project = type(board.project) == "table" and board.project or {}

  local key = value_to_text(board.projectKey)
    or value_to_text(location.projectKey)
    or value_to_text(project.key)
    or "-"
  local name = value_to_text(board.projectName)
    or value_to_text(location.projectName)
    or value_to_text(location.name)
    or value_to_text(project.name)
    or key

  return clean_jira_text(key), clean_jira_text(name)
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

local function select_sprints_for_display(sprints)
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
  for _, s in ipairs(sprints or {}) do
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
  return display_sprints
end

local function build_project_sprints_report(project_key, project_name, board_name, sprints, opts)
  opts = opts or {}
  local show_story_points = opts.show_story_points == true
  local display_sprints = select_sprints_for_display(sprints)

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
    local prefix = is_current and "  [CURRENT] " or "  - "
    local suffix = ""
    table.insert(lines, string.format("%s%s [state:%s] [issues:%d]%s", prefix, sprint.name, sprint.state, #sprint.issues, suffix))
    if #sprint.issues == 0 then
      table.insert(lines, "      (no issues)")
    else
      for _, issue in ipairs(sprint.issues) do
        local issue_label = string.format(
          "[%s] %s [status:%s] [assignee:%s]",
          markdown_escape_inline(issue.key),
          markdown_escape_inline(issue.summary),
          markdown_escape_inline(issue.status),
          markdown_escape_inline(issue.assignee)
        )
        if show_story_points then
          issue_label = issue_label .. string.format(" [sp:%s]", markdown_escape_inline(issue.story_points or "-"))
        end
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

local function parse_story_points_number(value)
  local n = tonumber(value)
  if n then
    return n
  end
  local s = tostring(value or "")
  s = s:match("[-+]?%d+%.?%d*")
  return tonumber(s)
end

local function is_in_progress_status(status)
  local s = string.lower(tostring(status or ""))
  if s == "" or is_done_status(s) then
    return false
  end
  for _, token in ipairs({ "progress", "review", "test", "qa", "develop", "doing", "implement", "code", "ready for" }) do
    if s:find(token, 1, true) then
      return true
    end
  end
  return false
end

local function is_blocked_status(status)
  local s = string.lower(tostring(status or ""))
  for _, token in ipairs({ "block", "imped", "stuck", "waiting", "hold", "depend" }) do
    if s:find(token, 1, true) then
      return true
    end
  end
  return false
end

local function classify_issue_status(status)
  if is_done_status(status) then
    return "done"
  end
  if is_blocked_status(status) then
    return "blocked"
  end
  if is_in_progress_status(status) then
    return "in_progress"
  end
  return "todo"
end

local function build_assignee_current_sprint_report(project_key, project_name, board_name, sprint, assignee_name, issues)
  local lines = {}
  table.insert(lines, string.format("Project: %s [%s]", project_name, project_key))
  table.insert(lines, string.format("Board: %s", board_name))
  table.insert(lines, string.format("Sprint: %s [state:%s]", sprint.name, sprint.state))
  table.insert(lines, string.format("Assignee: %s", assignee_name))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")

  local done = {}
  local in_progress = {}
  local todo = {}
  local blocked = {}
  local status_counts = {}

  local total_sp = 0
  local known_sp = 0
  local missing_sp = 0
  local done_sp = 0
  local in_progress_sp = 0
  local todo_sp = 0
  local blocked_sp = 0
  local largest_remaining_sp = 0
  local largest_remaining_key = nil

  for _, issue in ipairs(issues) do
    local bucket = classify_issue_status(issue.status)
    status_counts[issue.status] = (status_counts[issue.status] or 0) + 1

    local sp = parse_story_points_number(issue.story_points)
    if sp then
      known_sp = known_sp + 1
      total_sp = total_sp + sp
      if bucket == "done" then
        done_sp = done_sp + sp
      elseif bucket == "in_progress" then
        in_progress_sp = in_progress_sp + sp
        if sp > largest_remaining_sp then
          largest_remaining_sp = sp
          largest_remaining_key = issue.key
        end
      elseif bucket == "blocked" then
        blocked_sp = blocked_sp + sp
        if sp > largest_remaining_sp then
          largest_remaining_sp = sp
          largest_remaining_key = issue.key
        end
      else
        todo_sp = todo_sp + sp
        if sp > largest_remaining_sp then
          largest_remaining_sp = sp
          largest_remaining_key = issue.key
        end
      end
    else
      missing_sp = missing_sp + 1
    end

    if bucket == "done" then
      table.insert(done, issue)
    elseif bucket == "in_progress" then
      table.insert(in_progress, issue)
    elseif bucket == "blocked" then
      table.insert(blocked, issue)
    else
      table.insert(todo, issue)
    end
  end

  table.sort(done, function(a, b) return a.key < b.key end)
  table.sort(in_progress, function(a, b) return a.key < b.key end)
  table.sort(blocked, function(a, b) return a.key < b.key end)
  table.sort(todo, function(a, b) return a.key < b.key end)

  local total = #issues
  local done_count = #done
  local in_progress_count = #in_progress
  local blocked_count = #blocked
  local todo_count = #todo
  local completion_pct = (total > 0) and math.floor((done_count * 100) / total + 0.5) or 0
  local done_sp_pct = (total_sp > 0) and math.floor((done_sp * 100) / total_sp + 0.5) or 0
  local remaining_count = math.max(0, total - done_count)
  local remaining_sp = in_progress_sp + blocked_sp + todo_sp
  local sp_coverage_pct = (total > 0) and math.floor((known_sp * 100) / total + 0.5) or 0
  local avg_sp_per_estimated_issue = (known_sp > 0) and (total_sp / known_sp) or 0
  local avg_remaining_sp_per_issue = (remaining_count > 0) and (remaining_sp / remaining_count) or 0

  table.insert(lines, "Summary:")
  table.insert(lines, string.format("  - Total issues: %d", total))
  table.insert(lines, string.format("  - Done: %d (%d%%)", done_count, completion_pct))
  table.insert(lines, string.format("  - In progress: %d", in_progress_count))
  table.insert(lines, string.format("  - Blocked: %d", blocked_count))
  table.insert(lines, string.format("  - Not started / other: %d", todo_count))
  if known_sp > 0 then
    table.insert(lines, string.format("  - Story points: total %.1f | done %.1f (%d%%) | in progress %.1f | blocked %.1f | remaining %.1f", total_sp, done_sp, done_sp_pct, in_progress_sp, blocked_sp, remaining_sp))
  else
    table.insert(lines, "  - Story points: unavailable")
  end
  table.insert(lines, "")

  table.insert(lines, "Story Point Analysis:")
  if known_sp > 0 then
    table.insert(lines, string.format("  - Estimate coverage: %d/%d issues (%d%%)", known_sp, total, sp_coverage_pct))
    table.insert(lines, string.format("  - Completed effort vs completed tickets: %d%% SP vs %d%% issues", done_sp_pct, completion_pct))
    table.insert(lines, string.format("  - Average SP per estimated issue: %.1f", avg_sp_per_estimated_issue))
    if remaining_count > 0 then
      table.insert(lines, string.format("  - Remaining effort density: %.1f SP over %d issues (avg %.1f SP/issue)", remaining_sp, remaining_count, avg_remaining_sp_per_issue))
    end
    if largest_remaining_key then
      table.insert(lines, string.format("  - Largest remaining estimated task: %s (%.1f SP)", markdown_escape_inline(largest_remaining_key), largest_remaining_sp))
    end
    if missing_sp > 0 then
      table.insert(lines, string.format("  - Missing estimates: %d issue%s", missing_sp, missing_sp == 1 and "" or "s"))
    end
  else
    table.insert(lines, "  - No usable story point estimates in current sprint items")
  end
  table.insert(lines, "")

  table.insert(lines, "Risk Signals:")
  local signals = {}
  if blocked_count > 0 then
    table.insert(signals, string.format("Blocked work exists (%d issue%s)", blocked_count, blocked_count == 1 and "" or "s"))
  end
  if todo_count >= math.max(3, done_count + 1) then
    table.insert(signals, "Large share of tasks still not started")
  end
  if total >= 6 and done_count <= 1 then
    table.insert(signals, "Low completion relative to workload size")
  end
  if in_progress_count >= 4 then
    table.insert(signals, "High WIP may indicate context switching risk")
  end
  if known_sp > 0 and done_sp_pct < 25 and total_sp >= 10 then
    table.insert(signals, "Low story-point burn so far")
  end
  if known_sp > 0 and done_sp_pct + 15 < completion_pct then
    table.insert(signals, "More tickets than effort are completed; heavier work may still be outstanding")
  end
  if known_sp > 0 and blocked_sp >= 5 and blocked_sp >= (total_sp * 0.25) then
    table.insert(signals, "Blocked items represent a significant share of remaining story points")
  end
  if missing_sp >= 2 then
    table.insert(signals, "Several sprint items are unestimated, reducing realism of effort forecast")
  end
  if #signals == 0 then
    table.insert(signals, "No obvious risk signal from status distribution")
  end
  for _, signal in ipairs(signals) do
    table.insert(lines, "  - " .. markdown_escape_inline(signal))
  end
  table.insert(lines, "")

  table.insert(lines, "Status Breakdown:")
  local statuses = {}
  for status, count in pairs(status_counts) do
    table.insert(statuses, { status = status, count = count })
  end
  table.sort(statuses, function(a, b)
    if a.count ~= b.count then
      return a.count > b.count
    end
    return a.status < b.status
  end)
  for _, entry in ipairs(statuses) do
    table.insert(lines, string.format("  - %s: %d", markdown_escape_inline(entry.status), entry.count))
  end
  table.insert(lines, "")

  local function append_issue_group(title, group)
    table.insert(lines, title)
    if #group == 0 then
      table.insert(lines, "  - (none)")
      table.insert(lines, "")
      return
    end
    for _, issue in ipairs(group) do
      local label = string.format(
        "[%s] %s [status:%s] [sp:%s] [due:%s]",
        markdown_escape_inline(issue.key),
        markdown_escape_inline(issue.summary),
        markdown_escape_inline(issue.status),
        markdown_escape_inline(issue.story_points or "-"),
        markdown_escape_inline(issue.due_date or "-")
      )
      label = markdown_strike_if_done(label, issue.status)
      table.insert(lines, "  - " .. label)
    end
    table.insert(lines, "")
  end

  append_issue_group("Blocked:", blocked)
  append_issue_group("In Progress:", in_progress)
  append_issue_group("Not Started / Other:", todo)
  append_issue_group("Done:", done)

  return table.concat(lines, "\n")
end

local function latex_escape(text)
  local s = tostring(text or "")
  local map = {
    ["\\"] = "\\textbackslash{}",
    ["{"] = "\\{",
    ["}"] = "\\}",
    ["$"] = "\\$",
    ["&"] = "\\&",
    ["#"] = "\\#",
    ["_"] = "\\_",
    ["%"] = "\\%",
    ["~"] = "\\textasciitilde{}",
    ["^"] = "\\textasciicircum{}",
  }
  return (s:gsub("[\\{}$&#_%%~%^]", map))
end

local function latex_one_line_title(text, max_chars)
  local s = tostring(text or "")
  s = s:gsub("[%s\r\n\t]+", " ")
  s = vim.trim(s)
  max_chars = tonumber(max_chars) or 72
  if #s > max_chars and max_chars > 3 then
    s = s:sub(1, max_chars - 3) .. "..."
  end
  return "\\mbox{" .. latex_escape(s) .. "}"
end

local function latex_one_line_cell(text, max_chars)
  local s = tostring(text or "")
  s = s:gsub("[%s\r\n\t]+", " ")
  s = vim.trim(s)
  max_chars = tonumber(max_chars) or 48
  if #s > max_chars and max_chars > 3 then
    s = s:sub(1, max_chars - 3) .. "..."
  end
  return "\\mbox{" .. latex_escape(s) .. "}"
end

local function paginate_items(items, page_size)
  local out = {}
  local list = items or {}
  page_size = math.max(1, tonumber(page_size) or 1)
  if #list == 0 then
    return { {} }
  end
  local i = 1
  while i <= #list do
    local chunk = {}
    local last = math.min(i + page_size - 1, #list)
    for j = i, last do
      table.insert(chunk, list[j])
    end
    table.insert(out, chunk)
    i = last + 1
  end
  return out
end

local function retro_rows_per_page()
  local configured = tonumber(vim.g.jira_retro_rows_per_page)
  if configured and configured >= 8 and configured <= 60 then
    return math.floor(configured)
  end
  -- Calibrated for 16:9 + scriptsize + single-line rows.
  return 28
end

local function retro_epic_label(issue)
  local epic_key = clean_jira_text(issue and issue.epic_key or "")
  local epic_name = clean_jira_text(issue and issue.epic_name or "")
  if epic_key == "" or epic_key == "-" then
    return (epic_name ~= "" and epic_name) or "(No Epic)"
  end
  if epic_name == "" or epic_name == "(No Epic)" then
    return epic_key
  end
  return epic_key .. " - " .. epic_name
end

local function append_last_sprint_ticket_rows(lines, issues)
  if #issues == 0 then
    table.insert(lines, "- & - & - & \\mbox{No work items found} \\\\")
    return
  end

  local current_epic = nil
  for _, issue in ipairs(issues) do
    local epic_label = retro_epic_label(issue)
    if epic_label ~= current_epic then
      current_epic = epic_label
      table.insert(lines, "\\multicolumn{4}{l}{" .. latex_one_line_cell("Epic: " .. epic_label, 120) .. "} \\\\")
    end

    local assignee = (issue.assignee ~= "" and issue.assignee ~= "-") and issue.assignee or "Unassigned"
    table.insert(lines, string.format(
      "%s & %s & %s & %s \\\\",
      latex_escape(issue.key),
      latex_one_line_cell(issue.status, 30),
      latex_one_line_cell(assignee, 20),
      latex_one_line_title(issue.summary, 72)
    ))
  end
end

local function append_next_sprint_ticket_rows(lines, issues)
  if #issues == 0 then
    table.insert(lines, "- & \\mbox{No work items found} & - \\\\")
    return
  end

  local current_epic = nil
  for _, issue in ipairs(issues) do
    local epic_label = retro_epic_label(issue)
    if epic_label ~= current_epic then
      current_epic = epic_label
      table.insert(lines, "\\multicolumn{3}{l}{" .. latex_one_line_cell("Epic: " .. epic_label, 120) .. "} \\\\")
    end

    local assignee = (issue.assignee ~= "" and issue.assignee ~= "-") and issue.assignee or "Unassigned"
    table.insert(lines, string.format(
      "%s & %s & %s \\\\",
      latex_escape(issue.key),
      latex_one_line_title(issue.summary, 80),
      latex_one_line_cell(assignee, 24)
    ))
  end
end

local function parse_iso_date_ymd(value)
  local s = tostring(value or "")
  local ymd = s:match("(%d%d%d%d%-%d%d%-%d%d)")
  if ymd and #ymd == 10 then
    return ymd
  end
  return nil
end

local function summarize_issues_for_retro(issues)
  local summary = {
    total = 0,
    done = 0,
    in_progress = 0,
    blocked = 0,
    todo = 0,
  }

  for _, issue in ipairs(issues or {}) do
    summary.total = summary.total + 1
    local bucket = classify_issue_status(issue.status)
    if bucket == "done" then
      summary.done = summary.done + 1
    elseif bucket == "in_progress" then
      summary.in_progress = summary.in_progress + 1
    elseif bucket == "blocked" then
      summary.blocked = summary.blocked + 1
    else
      summary.todo = summary.todo + 1
    end

  end

  return summary
end

local function select_retro_last_sprint(sprints, today_ymd)
  local candidates = {}
  for _, sprint in ipairs(sprints or {}) do
    local state = string.lower(sprint.state or "")
    if state == "active" or state == "closed" then
      table.insert(candidates, sprint)
    end
  end
  if #candidates == 0 then
    return nil, false
  end

  table.sort(candidates, function(a, b)
    local a_end = tostring(a.end_date or "")
    local b_end = tostring(b.end_date or "")
    if a_end ~= b_end then
      return a_end < b_end
    end
    return tostring(a.id or "") < tostring(b.id or "")
  end)

  for _, sprint in ipairs(candidates) do
    if parse_iso_date_ymd(sprint.end_date) == today_ymd then
      return sprint, true
    end
  end

  local latest_past = nil
  for _, sprint in ipairs(candidates) do
    local end_ymd = parse_iso_date_ymd(sprint.end_date)
    if end_ymd and end_ymd <= today_ymd then
      if not latest_past or end_ymd > (parse_iso_date_ymd(latest_past.end_date) or "") then
        latest_past = sprint
      end
    end
  end
  if latest_past then
    return latest_past, false
  end

  return candidates[#candidates], false
end

local function select_retro_next_sprint(sprints)
  local future = {}
  for _, sprint in ipairs(sprints or {}) do
    if string.lower(sprint.state or "") == "future" then
      table.insert(future, sprint)
    end
  end
  if #future == 0 then
    return nil
  end

  table.sort(future, function(a, b)
    local a_start = tostring(a.start_date or "")
    local b_start = tostring(b.start_date or "")
    if a_start ~= b_start then
      return a_start < b_start
    end
    local a_end = tostring(a.end_date or "")
    local b_end = tostring(b.end_date or "")
    if a_end ~= b_end then
      return a_end < b_end
    end
    return tostring(a.id or "") < tostring(b.id or "")
  end)

  return future[1]
end

local function extract_sprint_issues_for_retro(board_id, sprint_id, on_done)
  local function normalize_epic_fields(parent_key, parent_name)
    local epic_key = clean_jira_text(parent_key or "")
    local epic_name = clean_jira_text(parent_name or "")
    if epic_key == "" then
      epic_key = "-"
    end
    if epic_name == "" then
      epic_name = "(No Epic)"
    end
    return epic_key, epic_name
  end

  local function enrich_missing_epics(issues, on_enriched)
    local missing = {}
    local issue_by_key = {}
    for _, issue in ipairs(issues or {}) do
      issue_by_key[issue.key] = issue
      if issue.epic_key == "-" then
        table.insert(missing, issue.key)
      end
    end

    if #missing == 0 then
      on_enriched()
      return
    end

    local idx = 1
    local active = 0
    local max_concurrency = 6

    local function maybe_done()
      if idx > #missing and active == 0 then
        on_enriched()
      end
    end

    local function pump()
      while active < max_concurrency and idx <= #missing do
        local issue_key = missing[idx]
        idx = idx + 1
        active = active + 1

        local view_cmd = {
          "acli", "jira", "workitem", "view", issue_key,
          "--fields", "parent,customfield_10014,customfield_10018,Epic Link,parent epic,epic,names",
          "--json",
        }

        run_cmd_async(view_cmd, function(view_output, view_code)
          if view_code == 0 then
            local decoded = decode_json(view_output)
            if decoded then
              local _, _, parent_key, parent_name = extract_status_assignee_parent(decoded)
              local epic_key, epic_name = normalize_epic_fields(parent_key, parent_name)
              local issue = issue_by_key[issue_key]
              if issue and epic_key ~= "-" then
                issue.epic_key = epic_key
                issue.epic_name = epic_name
              end
            end
          end

          active = active - 1
          pump()
          maybe_done()
        end)
      end
    end

    pump()
  end

  local sprint_issue_cmd = {
    "acli", "jira", "sprint", "list-workitems",
    "--board", tostring(board_id),
    "--sprint", tostring(sprint_id),
    "--fields", "key,summary,status,assignee,parent,customfield_10014",
    "--paginate",
    "--json",
  }
  run_cmd_async(sprint_issue_cmd, function(output, code)
    if code ~= 0 then
      on_done({}, "Failed to load sprint work items: " .. tostring(output or ""))
      return
    end

    local issue_rows = decode_list_output(output, extract_workitems)
    if not issue_rows then
      on_done({}, "Could not parse sprint work items JSON output")
      return
    end

    local issues = {}
    for _, item in ipairs(issue_rows) do
      local key, summary = extract_key_summary(item)
      if key then
        local status, assignee, parent_key, parent_name = extract_status_assignee_parent(item)
        local epic_key, epic_name = normalize_epic_fields(parent_key, parent_name)
        table.insert(issues, {
          key = clean_jira_text(key),
          summary = clean_jira_text(summary),
          status = clean_jira_text(status),
          assignee = clean_jira_text(assignee),
          epic_key = epic_key,
          epic_name = epic_name,
        })
      end
    end

    enrich_missing_epics(issues, function()
      table.sort(issues, function(a, b)
        local a_epic = string.lower((a.epic_name or "") .. " " .. (a.epic_key or ""))
        local b_epic = string.lower((b.epic_name or "") .. " " .. (b.epic_key or ""))
        if a_epic ~= b_epic then
          return a_epic < b_epic
        end
        return tostring(a.key or "") < tostring(b.key or "")
      end)
      on_done(issues, nil)
    end)
  end)
end

local function choose_retro_board(project, board_rows)
  local candidates = {}
  for _, board in ipairs(board_rows or {}) do
    local board_id, board_name = extract_board_id_name(board)
    if board_id then
      local board_project_key = extract_board_project_key_name(board)
      table.insert(candidates, {
        id = board_id,
        name = clean_jira_text(board_name),
        project_key = clean_jira_text(board_project_key),
      })
    end
  end

  if #candidates == 0 then
    return nil
  end

  local wanted_key = string.lower(clean_jira_text(project.key or ""))
  table.sort(candidates, function(a, b)
    local a_exact = (string.lower(a.project_key) == wanted_key) and 1 or 0
    local b_exact = (string.lower(b.project_key) == wanted_key) and 1 or 0
    if a_exact ~= b_exact then
      return a_exact > b_exact
    end

    local a_has_key = string.lower(a.name):find(wanted_key, 1, true) and 1 or 0
    local b_has_key = string.lower(b.name):find(wanted_key, 1, true) and 1 or 0
    if a_has_key ~= b_has_key then
      return a_has_key > b_has_key
    end

    local aid = tonumber(a.id) or 0
    local bid = tonumber(b.id) or 0
    if aid ~= bid then
      return aid < bid
    end
    return a.name < b.name
  end)

  return candidates[1]
end

local function open_latex_presentation_tab(latex)
  vim.cmd("tabnew")
  local buf = vim.api.nvim_get_current_buf()
  local lines = vim.split(latex or "", "\n", { plain = true })
  if #lines == 0 then
    lines = { "" }
  end

  vim.bo[buf].buftype = ""
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "tex"
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  pcall(vim.api.nvim_buf_set_name, buf, "jira-retro-" .. os.date("%Y%m%d-%H%M%S") .. ".tex")
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

local function build_retro_presentation_latex(reports, today_ymd)
  local lines = {
    "\\documentclass[aspectratio=169,10pt]{beamer}",
    "\\usetheme{Madrid}",
    "\\usecolortheme{default}",
    "\\setbeamertemplate{navigation symbols}{}",
    "\\setbeamertemplate{footline}[frame number]",
    "\\usepackage[utf8]{inputenc}",
    "\\usepackage[T1]{fontenc}",
    "\\usepackage{array}",
    "\\usepackage{booktabs}",
    "\\usepackage{tabularx}",
    "\\usepackage{ragged2e}",
    "\\definecolor{BrandNavy}{HTML}{0E2A47}",
    "\\definecolor{BrandTeal}{HTML}{157A8A}",
    "\\definecolor{BrandSky}{HTML}{EAF3FA}",
    "\\definecolor{TextDark}{HTML}{1E2933}",
    "\\setbeamercolor{normal text}{fg=TextDark,bg=white}",
    "\\setbeamercolor{title}{fg=white,bg=BrandNavy}",
    "\\setbeamercolor{frametitle}{fg=white,bg=BrandNavy}",
    "\\setbeamercolor{subtitle}{fg=BrandSky}",
    "\\setbeamercolor{structure}{fg=BrandTeal}",
    "\\setbeamercolor{footline}{fg=white,bg=BrandNavy}",
    "\\setbeamerfont{title}{series=\\bfseries,size=\\Large}",
    "\\setbeamerfont{frametitle}{series=\\bfseries,size=\\large}",
    "\\setbeamerfont{subtitle}{size=\\normalsize}",
    "\\newcolumntype{Y}{>{\\RaggedRight\\arraybackslash}X}",
    "\\renewcommand{\\arraystretch}{1.12}",
    "\\setlength{\\tabcolsep}{4pt}",
    "\\title{End-of-Sprint Project Update}",
    "\\subtitle{Sprint Retrospective}",
    "\\author{Engineering Team}",
    "\\date{" .. latex_escape(today_ymd) .. "}",
    "",
    "\\begin{document}",
    "\\frame{\\titlepage}",
    "",
    "\\begin{frame}{Included Jira Spaces}",
    "\\begin{itemize}",
  }

  if #reports == 0 then
    table.insert(lines, "\\item No Jira spaces selected.")
  else
    for _, report in ipairs(reports) do
      local project_label = string.format("%s (%s)", report.project.name or report.project.key, report.project.key)
      if report.error then
        project_label = project_label .. " -- " .. report.error
      end
      table.insert(lines, "\\item " .. latex_escape(project_label))
    end
  end
  table.insert(lines, "\\end{itemize}")
  table.insert(lines, "\\end{frame}")
  table.insert(lines, "")

  for _, report in ipairs(reports) do
    local project_name = report.project.name or report.project.key
    local project_key = report.project.key or "-"
    local board_name = report.board and report.board.name or "(no board)"
    local title_prefix = string.format("%s [%s]", project_name, project_key)
    local short_project = project_name

    if report.error then
      table.insert(lines, "\\begin{frame}[t]{Project Overview - " .. latex_escape(title_prefix) .. "}")
      table.insert(lines, "Could not build report: " .. latex_escape(report.error))
      table.insert(lines, "\\end{frame}")
      table.insert(lines, "")
    elseif not report.last_sprint then
      table.insert(lines, "\\begin{frame}[t]{Project Overview - " .. latex_escape(title_prefix) .. "}")
      table.insert(lines, "No last sprint found for selected board: " .. latex_escape(board_name) .. ".")
      table.insert(lines, "\\end{frame}")
      table.insert(lines, "")
    else
      local sprint = report.last_sprint
      local last_issues = report.last_issues or {}
      local next_items = report.next_issues or {}
      local summary = summarize_issues_for_retro(last_issues)
      local done_pct = (summary.total > 0) and math.floor((summary.done * 100) / summary.total + 0.5) or 0
      local sprint_end = parse_iso_date_ymd(sprint.end_date) or "-"

      local rows_per_page = retro_rows_per_page()
      local last_pages = paginate_items(last_issues, rows_per_page)
      local next_pages = paginate_items(next_items, rows_per_page)
      local combined_rows_capacity = math.max(8, rows_per_page - 8)
      local can_render_combined_tickets = report.next_sprint ~= nil
        and (#last_issues + #next_items) <= combined_rows_capacity

      -- Main summary page.
      table.insert(lines, "\\begin{frame}[t]{Summary - " .. latex_escape(short_project) .. "}")
      table.insert(lines, "\\scriptsize")
      table.insert(lines, "\\textbf{Board}: " .. latex_escape(board_name) .. "\\\\")
      table.insert(lines, "\\textbf{Sprint}: " .. latex_escape(sprint.name) .. " [state: " .. latex_escape(sprint.state) .. "]\\\\")
      table.insert(lines, "\\textbf{Sprint End Date}: " .. latex_escape(sprint_end) .. "\\\\")
      table.insert(lines, "\\vspace{0.15cm}")
      table.insert(lines, "\\begin{tabular}{l r}")
      table.insert(lines, "Total Work Items & " .. tostring(summary.total) .. " \\\\")
      table.insert(lines, "Done & " .. tostring(summary.done) .. " (" .. tostring(done_pct) .. "\\%) \\\\")
      table.insert(lines, "In Progress & " .. tostring(summary.in_progress) .. " \\\\")
      table.insert(lines, "Blocked & " .. tostring(summary.blocked) .. " \\\\")
      table.insert(lines, "Todo / Other & " .. tostring(summary.todo) .. " \\\\")
      table.insert(lines, "\\end{tabular}")
      table.insert(lines, "\\end{frame}")
      table.insert(lines, "")

      if can_render_combined_tickets then
        local next_sprint = report.next_sprint
        table.insert(lines, "\\begin{frame}[t]{Tickets - " .. latex_escape(short_project) .. "}")
        table.insert(lines, "\\scriptsize")
        table.insert(lines, "\\textbf{Last Sprint}: " .. latex_escape(sprint.name) .. " \\quad \\textbf{Next Sprint}: " .. latex_escape(next_sprint.name) .. "\\\\[0.08cm]")
        table.insert(lines, "\\textbf{Last Sprint}\\\\[0.05cm]")
        table.insert(lines, "\\begin{tabular}{p{1.5cm}l p{2.0cm}l}")
        table.insert(lines, "\\textbf{Key} & \\textbf{Status} & \\textbf{Assignee} & \\textbf{Summary} \\\\")
        table.insert(lines, "\\hline")
        append_last_sprint_ticket_rows(lines, last_issues)
        table.insert(lines, "\\end{tabular}")
        table.insert(lines, "\\\\[0.12cm]")
        table.insert(lines, "\\textbf{Next Sprint}\\\\[0.05cm]")
        table.insert(lines, "\\begin{tabular}{p{1.8cm}l p{2.6cm}}")
        table.insert(lines, "\\textbf{Key} & \\textbf{Summary} & \\textbf{Assignee} \\\\")
        table.insert(lines, "\\hline")
        append_next_sprint_ticket_rows(lines, next_items)
        table.insert(lines, "\\end{tabular}")
        table.insert(lines, "\\end{frame}")
        table.insert(lines, "")
      else
      -- Last sprint ticket pages (all pages).
      for page_idx, page_items in ipairs(last_pages) do
        table.insert(lines, "\\begin{frame}[t]{Last Sprint - " .. latex_escape(short_project) .. "}")
        table.insert(lines, "\\scriptsize")
        table.insert(lines, "\\begin{tabular}{p{1.5cm}l p{2.0cm}l}")
        table.insert(lines, "\\textbf{Key} & \\textbf{Status} & \\textbf{Assignee} & \\textbf{Summary} \\\\")
        table.insert(lines, "\\hline")
        append_last_sprint_ticket_rows(lines, page_items)
        table.insert(lines, "\\end{tabular}")
        table.insert(lines, "\\end{frame}")
        table.insert(lines, "")
      end

      -- Next sprint ticket pages (all pages).
      if report.next_sprint then
        local next_sprint = report.next_sprint
        for page_idx, page_items in ipairs(next_pages) do
          table.insert(lines, "\\begin{frame}[t]{Next Sprint - " .. latex_escape(short_project) .. "}")
          table.insert(lines, "\\scriptsize")
          table.insert(lines, "\\begin{tabular}{p{1.8cm}l p{2.6cm}}")
          table.insert(lines, "\\textbf{Key} & \\textbf{Summary} & \\textbf{Assignee} \\\\")
          table.insert(lines, "\\hline")
          append_next_sprint_ticket_rows(lines, page_items)
          table.insert(lines, "\\end{tabular}")
          table.insert(lines, "\\end{frame}")
          table.insert(lines, "")
        end
      else
        table.insert(lines, "\\begin{frame}[t]{Next Sprint - " .. latex_escape(short_project) .. "}")
        table.insert(lines, "\\scriptsize")
        table.insert(lines, "No future sprint found.")
        table.insert(lines, "\\end{frame}")
        table.insert(lines, "")
      end
      end
    end
  end

  table.insert(lines, "\\end{document}")
  return table.concat(lines, "\n")
end

local function jira_generate_retro_presentation_for_projects(projects)
  local today_ymd = os.date("%Y-%m-%d")
  local reports = {}
  local idx = 1

  local function finish()
    spinner_stop()
    local latex = build_retro_presentation_latex(reports, today_ymd)
    open_latex_presentation_tab(latex)
    vim.notify("Generated Jira sprint retrospective LaTeX presentation", vim.log.levels.INFO)
  end

  local function process_next()
    if idx > #projects then
      finish()
      return
    end

    local project = projects[idx]
    idx = idx + 1

    local function append_error(err)
      table.insert(reports, {
        project = project,
        error = err,
      })
      process_next()
    end

    spinner_start("Jira: loading boards for " .. project.key .. " ...")
    local board_search_cmd = {
      "acli", "jira", "board", "search",
      "--project", project.key,
      "--type", "scrum",
      "--paginate",
      "--json",
    }

    run_cmd_async(board_search_cmd, function(board_output, board_code)
      local function with_board_rows(board_rows)
        local board = choose_retro_board(project, board_rows)
        if not board then
          append_error("No scrum board found")
          return
        end

        spinner_start("Jira: loading sprints for " .. project.key .. " ...")
        local sprint_list_cmd = {
          "acli", "jira", "board", "list-sprints",
          "--id", tostring(board.id),
          "--state", "active,future,closed",
          "--paginate",
          "--json",
        }
        run_cmd_async(sprint_list_cmd, function(sprint_output, sprint_code)
          if sprint_code ~= 0 then
            append_error("Failed to load sprints")
            return
          end

          local sprint_rows = decode_list_output(sprint_output, extract_sprints)
          if not sprint_rows then
            append_error("Could not parse sprint list JSON")
            return
          end

          local sprints = {}
          for _, raw in ipairs(sprint_rows) do
            local sprint = extract_sprint_info(raw)
            if sprint then
              table.insert(sprints, sprint)
            end
          end

          local last_sprint, last_ends_today = select_retro_last_sprint(sprints, today_ymd)
          local next_sprint = select_retro_next_sprint(sprints)
          local report = {
            project = project,
            board = board,
            last_sprint = last_sprint,
            last_ends_today = last_ends_today,
            last_issues = {},
            next_sprint = next_sprint,
            next_issues = {},
          }

          local function finalize_project()
            table.insert(reports, report)
            process_next()
          end

          local function load_next_sprint_items()
            if not next_sprint then
              finalize_project()
              return
            end

            spinner_start("Jira: loading next sprint items for " .. project.key .. " ...")
            extract_sprint_issues_for_retro(board.id, next_sprint.id, function(next_issues, next_err)
              report.next_issues = next_issues or {}
              report.next_error = next_err
              finalize_project()
            end)
          end

          if not last_sprint then
            load_next_sprint_items()
            return
          end

          spinner_start("Jira: loading last sprint tickets for " .. project.key .. " ...")
          extract_sprint_issues_for_retro(board.id, last_sprint.id, function(last_issues, last_err)
            report.last_issues = last_issues or {}
            report.last_error = last_err
            load_next_sprint_items()
          end)
        end)
      end

      if board_code == 0 then
        local board_rows = decode_list_output(board_output, extract_boards)
        if board_rows and #board_rows > 0 then
          with_board_rows(board_rows)
          return
        end
      end

      local fallback_board_cmd = {
        "acli", "jira", "board", "search",
        "--type", "scrum",
        "--paginate",
        "--json",
      }
      run_cmd_async(fallback_board_cmd, function(fallback_output, fallback_code)
        if fallback_code ~= 0 then
          append_error("Failed to load project scrum boards")
          return
        end

        local all_rows = decode_list_output(fallback_output, extract_boards)
        if not all_rows then
          append_error("Could not parse fallback scrum board list")
          return
        end

        local filtered = {}
        for _, board in ipairs(all_rows) do
          local bkey = extract_board_project_key_name(board)
          if string.lower(clean_jira_text(bkey)) == string.lower(clean_jira_text(project.key)) then
            table.insert(filtered, board)
          end
        end
        with_board_rows(filtered)
      end)
    end)
  end

  process_next()
end

local function jira_sprint_retro_presentation(opts)
  opts = opts or {}
  spinner_start("Jira: loading projects ...")
  local project_list_cmd = { "acli", "jira", "project", "list", "--paginate", "--json" }
  run_cmd_async(project_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_sprint_retro_presentation:project-list:command-failed", project_list_cmd, output)
      vim.notify("Failed to load Jira projects:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      spinner_stop()
      jira_debug_log("jira_sprint_retro_presentation:project-list:json-parse-failed", project_list_cmd, output)
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
      prompt = "Jira Spaces (multi)> ",
      query = opts.query,
      previewer = false,
      fzf_opts = {
        ["--ansi"] = false,
        ["--multi"] = true,
        ["--header"] = "Tab to select Jira spaces, Enter to generate sprint retro LaTeX deck",
      },
      actions = {
        ['default'] = function(selected)
          local chosen = {}
          local seen = {}
          for _, entry in ipairs(selected or {}) do
            local project = project_by_entry[entry]
            if project and not seen[project.key] then
              seen[project.key] = true
              table.insert(chosen, project)
            end
          end

          if #chosen == 0 then
            vim.notify("No Jira spaces selected", vim.log.levels.WARN)
            return
          end

          jira_generate_retro_presentation_for_projects(chosen)
        end,
      },
    })
  end)
end

local function select_primary_active_sprint(sprints)
  local active = {}
  for _, sprint in ipairs(sprints or {}) do
    if string.lower(sprint.state or "") == "active" then
      table.insert(active, sprint)
    end
  end
  if #active == 0 then
    return nil, 0
  end

  table.sort(active, function(a, b)
    local a_end = tostring(a.end_date or "")
    local b_end = tostring(b.end_date or "")
    if a_end ~= "" and b_end ~= "" and a_end ~= b_end then
      return a_end < b_end
    end
    local a_start = tostring(a.start_date or "")
    local b_start = tostring(b.start_date or "")
    if a_start ~= "" and b_start ~= "" and a_start ~= b_start then
      return a_start > b_start
    end
    local aid = tonumber(a.id) or 0
    local bid = tonumber(b.id) or 0
    return aid > bid
  end)

  return active[1], #active
end

local function jira_current_sprint_assignee_overview_for_board(project_key, project_name, board_id, board_name)
  spinner_start("Jira: loading active sprint ...")
  local sprint_list_cmd = { "acli", "jira", "board", "list-sprints", "--id", tostring(board_id), "--state", "active", "--paginate", "--json" }
  run_cmd_async(sprint_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_current_sprint_assignee_overview:list-sprints:command-failed", sprint_list_cmd, output)
      vim.notify("Failed to load active sprint:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local sprint_rows = decode_list_output(output, extract_sprints)
    if not sprint_rows then
      spinner_stop()
      jira_debug_log("jira_current_sprint_assignee_overview:list-sprints:json-parse-failed", sprint_list_cmd, output)
      vim.notify("Could not parse sprint list JSON output", vim.log.levels.ERROR)
      return
    end

    local sprints = {}
    for _, raw in ipairs(sprint_rows) do
      local sprint = extract_sprint_info(raw)
      if sprint then
        table.insert(sprints, sprint)
      end
    end

    local sprint, active_count = select_primary_active_sprint(sprints)
    if not sprint then
      spinner_stop()
      vim.notify("No active sprint found for board " .. board_name, vim.log.levels.WARN)
      return
    end

    spinner_start("Jira: loading work items for " .. sprint.name .. " ...")
    local sprint_issue_cmd = {
      "acli", "jira", "sprint", "list-workitems",
      "--board", tostring(board_id),
      "--sprint", tostring(sprint.id),
      "--fields", "key,summary,status,assignee,priority,duedate,customfield_10057,customfield_10016",
      "--paginate",
      "--json",
    }
    run_cmd_async(sprint_issue_cmd, function(issue_output, issue_code)
      if issue_code ~= 0 then
        spinner_stop()
        jira_debug_log("jira_current_sprint_assignee_overview:list-workitems:command-failed", sprint_issue_cmd, issue_output)
        vim.notify("Failed to load sprint work items:\n" .. issue_output, vim.log.levels.ERROR)
        return
      end

      local issue_rows = decode_list_output(issue_output, extract_workitems)
      if not issue_rows then
        spinner_stop()
        jira_debug_log("jira_current_sprint_assignee_overview:list-workitems:json-parse-failed", sprint_issue_cmd, issue_output)
        vim.notify("Could not parse sprint work items JSON output", vim.log.levels.ERROR)
        return
      end

      local issues = {}
      local issue_by_key = {}
      for _, item in ipairs(issue_rows) do
        local key, summary = extract_key_summary(item)
        if key then
          local status, assignee = extract_status_assignee_parent(item)
          local issue = {
            key = clean_jira_text(key),
            summary = clean_jira_text(summary),
            status = clean_jira_text(status),
            assignee = clean_jira_text(assignee),
            story_points = clean_jira_text(extract_story_points(item) or "-"),
            due_date = clean_jira_text(extract_due_date(item) or "-"),
          }
          table.insert(issues, issue)
          issue_by_key[issue.key] = issue
        end
      end

      if #issues == 0 then
        spinner_stop()
        vim.notify("No work items found in active sprint " .. sprint.name, vim.log.levels.INFO)
        return
      end

      local assignee_map = {}
      local assignee_order = {}
      for _, issue in ipairs(issues) do
        local assignee_key = issue.assignee ~= "" and issue.assignee or "-"
        if not assignee_map[assignee_key] then
          assignee_map[assignee_key] = {}
          table.insert(assignee_order, assignee_key)
        end
        table.insert(assignee_map[assignee_key], issue)
      end

      local function enrich_missing_story_points_for_issues(target_issues, on_done)
        local missing_sp_keys = {}
        for _, issue in ipairs(target_issues) do
          if issue.story_points == "-" then
            table.insert(missing_sp_keys, issue.key)
          end
        end

        if #missing_sp_keys == 0 then
          on_done()
          return
        end

        local enrich_concurrency = 2
        local next_missing_idx = 1
        local in_flight = 0
        local remaining = #missing_sp_keys

        local function apply_story_points_from_output(key, raw_output)
          local decoded = decode_json(raw_output)
          if not decoded then
            return false
          end
          local sp_value = extract_story_points(decoded)
          if sp_value and sp_value ~= "" then
            local issue = issue_by_key[key]
            if issue then
              issue.story_points = clean_jira_text(sp_value)
            end
          end
          return true
        end

        local function maybe_finish()
          if remaining <= 0 and in_flight == 0 and next_missing_idx > #missing_sp_keys then
            on_done()
          end
        end

        local function enrich_missing()
          while in_flight < enrich_concurrency and next_missing_idx <= #missing_sp_keys do
            local missing_key = missing_sp_keys[next_missing_idx]
            next_missing_idx = next_missing_idx + 1
            in_flight = in_flight + 1

            local sp_view_cmd = {
              "acli", "jira", "workitem", "view", missing_key,
              "--fields", "customfield_10057,customfield_10016",
              "--json",
            }

            run_cmd_async(sp_view_cmd, function(sp_output, sp_code)
              if sp_code == 0 then
                if not apply_story_points_from_output(missing_key, sp_output) then
                  jira_debug_log(
                    "jira_current_sprint_assignee_overview:story-points-enrich:view-json-parse-failed:sprint-" .. tostring(sprint.id),
                    sp_view_cmd,
                    sp_output
                  )
                end
                in_flight = in_flight - 1
                remaining = remaining - 1
                enrich_missing()
                maybe_finish()
                return
              end

              local sp_view_all_cmd = {
                "acli", "jira", "workitem", "view", missing_key,
                "--fields", "*all",
                "--json",
              }
              run_cmd_async(sp_view_all_cmd, function(sp_all_output, sp_all_code)
                if sp_all_code == 0 then
                  if not apply_story_points_from_output(missing_key, sp_all_output) then
                    jira_debug_log(
                      "jira_current_sprint_assignee_overview:story-points-enrich:view-all-json-parse-failed:sprint-" .. tostring(sprint.id),
                      sp_view_all_cmd,
                      sp_all_output
                    )
                  end
                else
                  jira_debug_log(
                    "jira_current_sprint_assignee_overview:story-points-enrich:view-command-failed:sprint-" .. tostring(sprint.id),
                    sp_view_cmd,
                    sp_output
                  )
                  jira_debug_log(
                    "jira_current_sprint_assignee_overview:story-points-enrich:view-all-command-failed:sprint-" .. tostring(sprint.id),
                    sp_view_all_cmd,
                    sp_all_output
                  )
                end
                in_flight = in_flight - 1
                remaining = remaining - 1
                enrich_missing()
                maybe_finish()
              end)
            end)
          end
        end

        enrich_missing()
      end

      local assignee_entries = {}
      local assignee_by_entry = {}
      table.sort(assignee_order, function(a, b) return string.lower(a) < string.lower(b) end)
      for _, assignee in ipairs(assignee_order) do
        local label = assignee == "-" and "(Unassigned)" or assignee
        local entry = label
        table.insert(assignee_entries, entry)
        assignee_by_entry[entry] = assignee
      end

      spinner_stop()
      if active_count > 1 then
        vim.notify(
          string.format("Multiple active sprints found on board %s. Using: %s", board_name, sprint.name),
          vim.log.levels.WARN
        )
      end
      if #assignee_entries == 0 then
        vim.notify("No assignees found in active sprint " .. sprint.name, vim.log.levels.INFO)
        return
      end

      fzf.fzf_exec(assignee_entries, {
        prompt = "Jira Assignee> ",
        previewer = false,
        fzf_opts = { ["--ansi"] = false },
        actions = {
          ['default'] = function(selected)
            local entry = selected and selected[1]
            local assignee = entry and assignee_by_entry[entry] or nil
            if not assignee then
              return
            end
            local bucket = assignee_map[assignee] or {}
            local label = assignee == "-" and "(Unassigned)" or assignee
            spinner_start("Jira: enriching story points for " .. label .. " ...")
            enrich_missing_story_points_for_issues(bucket, function()
              spinner_stop()
              insert_block_at_cursor(
                build_assignee_current_sprint_report(project_key, project_name, board_name, sprint, label, bucket)
              )
            end)
          end,
        },
      })
    end)
  end)
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

      sprints = select_sprints_for_display(sprints)

      if #sprints == 0 then
        spinner_stop()
        insert_block_at_cursor(build_project_sprints_report(project_key, project_name, board_name, sprints, {
          show_story_points = false,
        }))
        return
      end

      spinner_start("Jira: loading sprint issues ...")
      local max_concurrency = 5
      local next_idx = 1
      local active = 0
      local story_points_cache = {}
      local enrich_story_points = vim.g.jira_sprint_story_points_enrich == true

      local function load_sprint_issues(sprint, done)
        local sprint_issue_cmd = {
          "acli", "jira", "sprint", "list-workitems",
          "--board", tostring(board_id),
          "--sprint", tostring(sprint.id),
          "--fields", "key,summary,status,assignee,customfield_10057,customfield_10016",
          "--paginate",
          "--json",
        }
        run_cmd_async(
          sprint_issue_cmd,
          function(issue_output, issue_code)
            if issue_code == 0 then
              local issue_rows = decode_list_output(issue_output, extract_workitems)
              if issue_rows then
                local missing_sp_keys = {}
                local seen_missing_sp_keys = {}
                local issue_index_by_key = {}
                for _, item in ipairs(issue_rows) do
                  local key, summary = extract_key_summary(item)
                  if key then
                    local status, assignee = extract_status_assignee_parent(item)
                    local story_points = extract_story_points(item) or "-"
                    local clean_key = clean_jira_text(key)
                    local cached_sp = story_points_cache[clean_key]
                    if story_points == "-" and cached_sp and cached_sp ~= "-" then
                      story_points = cached_sp
                    end
                    table.insert(sprint.issues, {
                      key = clean_key,
                      summary = clean_jira_text(summary),
                      status = clean_jira_text(status),
                      assignee = clean_jira_text(assignee),
                      story_points = clean_jira_text(story_points),
                    })
                    issue_index_by_key[clean_key] = #sprint.issues
                    if story_points ~= "-" then
                      story_points_cache[clean_key] = clean_jira_text(story_points)
                    elseif not seen_missing_sp_keys[clean_key] then
                      seen_missing_sp_keys[clean_key] = true
                      table.insert(missing_sp_keys, clean_key)
                    end
                  end
                end

                if enrich_story_points and #missing_sp_keys > 0 then
                  local enrich_concurrency = 2
                  local next_missing_idx = 1
                  local in_flight = 0
                  local remaining = #missing_sp_keys

                  local function maybe_finish()
                    if remaining <= 0 and in_flight == 0 and next_missing_idx > #missing_sp_keys then
                      done()
                    end
                  end

                  local function enrich_missing()
                    while in_flight < enrich_concurrency and next_missing_idx <= #missing_sp_keys do
                      local missing_key = missing_sp_keys[next_missing_idx]
                      next_missing_idx = next_missing_idx + 1
                      in_flight = in_flight + 1

                      local sp_view_cmd = {
                        "acli", "jira", "workitem", "view", missing_key,
                        "--fields", "customfield_10057,customfield_10016",
                        "--json",
                      }

                      local function apply_from_output(raw_output)
                        local decoded = decode_json(raw_output)
                        if not decoded then
                          return false
                        end
                        local sp_value = extract_story_points(decoded)
                        if sp_value and sp_value ~= "" then
                          local clean_sp = clean_jira_text(sp_value)
                          story_points_cache[missing_key] = clean_sp
                          if issue_index_by_key[missing_key] then
                            local issue_idx = issue_index_by_key[missing_key]
                            sprint.issues[issue_idx].story_points = clean_sp
                          end
                        else
                          story_points_cache[missing_key] = story_points_cache[missing_key] or "-"
                        end
                        return true
                      end

                      run_cmd_async(sp_view_cmd, function(sp_output, sp_code)
                        if sp_code == 0 then
                          if not apply_from_output(sp_output) then
                            jira_debug_log(
                              "jira_project_sprints:story-points-enrich:view-json-parse-failed:sprint-" .. tostring(sprint.id),
                              sp_view_cmd,
                              sp_output
                            )
                          end
                          in_flight = in_flight - 1
                          remaining = remaining - 1
                          enrich_missing()
                          maybe_finish()
                          return
                        end

                        -- Fallback for strict field restrictions.
                        local sp_view_all_cmd = {
                          "acli", "jira", "workitem", "view", missing_key,
                          "--fields", "*all",
                          "--json",
                        }
                        run_cmd_async(sp_view_all_cmd, function(sp_all_output, sp_all_code)
                          if sp_all_code == 0 then
                            if not apply_from_output(sp_all_output) then
                              jira_debug_log(
                                "jira_project_sprints:story-points-enrich:view-all-json-parse-failed:sprint-" .. tostring(sprint.id),
                                sp_view_all_cmd,
                                sp_all_output
                              )
                            end
                          else
                            story_points_cache[missing_key] = story_points_cache[missing_key] or "-"
                            jira_debug_log(
                              "jira_project_sprints:story-points-enrich:view-command-failed:sprint-" .. tostring(sprint.id),
                              sp_view_cmd,
                              sp_output
                            )
                            jira_debug_log(
                              "jira_project_sprints:story-points-enrich:view-all-command-failed:sprint-" .. tostring(sprint.id),
                              sp_view_all_cmd,
                              sp_all_output
                            )
                          end
                          in_flight = in_flight - 1
                          remaining = remaining - 1
                          enrich_missing()
                          maybe_finish()
                        end)
                      end)
                    end
                  end

                  enrich_missing()
                  return
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
              insert_block_at_cursor(build_project_sprints_report(project_key, project_name, board_name, sprints, {
                show_story_points = enrich_story_points,
              }))
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

          local function open_board_picker(board_rows)
            local board_entries = {}
            local board_by_entry = {}
            for _, board in ipairs(board_rows) do
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

          spinner_start("Jira: loading boards ...")
          local board_search_cmd = { "acli", "jira", "board", "search", "--project", project.key, "--type", "scrum", "--paginate", "--json" }
          run_cmd_async(board_search_cmd, function(board_output, board_code)
            if board_code ~= 0 then
              spinner_stop()
              jira_debug_log("jira_project_sprints:board-search:command-failed", board_search_cmd, board_output)
              vim.notify("Failed to load boards:\n" .. board_output, vim.log.levels.ERROR)
              return
            end

            local board_rows = decode_list_output(board_output, extract_boards)
            if not board_rows then
              spinner_stop()
              jira_debug_log("jira_project_sprints:board-search:json-parse-failed", board_search_cmd, board_output)
              vim.notify("Could not parse board search JSON output", vim.log.levels.ERROR)
              return
            end

            if #board_rows > 0 then
              open_board_picker(board_rows)
              return
            end

            -- Fallback: some spaces don't map via --project filter; offer all scrum boards.
            local board_search_all_cmd = { "acli", "jira", "board", "search", "--type", "scrum", "--paginate", "--json" }
            run_cmd_async(board_search_all_cmd, function(all_output, all_code)
              if all_code ~= 0 then
                spinner_stop()
                jira_debug_log("jira_project_sprints:board-search-fallback:command-failed", board_search_all_cmd, all_output)
                vim.notify("No project-scoped boards found, and fallback board search failed", vim.log.levels.ERROR)
                return
              end

              local all_rows = decode_list_output(all_output, extract_boards)
              if not all_rows then
                spinner_stop()
                jira_debug_log("jira_project_sprints:board-search-fallback:json-parse-failed", board_search_all_cmd, all_output)
                vim.notify("Could not parse fallback board search JSON output", vim.log.levels.ERROR)
                return
              end

              vim.notify(
                "No scrum boards found via project filter for " .. project.key .. "; showing all scrum boards",
                vim.log.levels.WARN
              )
              open_board_picker(all_rows)
            end)
          end)
        end,
      },
    })
  end)
end

local function build_sprint_tickets_report(project_key, project_name, board_name, sprint, tickets)
  local function fixed_width(text, width)
    local s = clean_jira_text(text or "-")
    local function display_width(v)
      return vim.fn.strdisplaywidth(v)
    end

    local function truncate_display(v, max_width)
      if display_width(v) <= max_width then
        return v
      end
      local suffix = (max_width > 3) and "..." or ""
      local suffix_w = display_width(suffix)
      local target = math.max(0, max_width - suffix_w)
      local out = ""
      for _, ch in ipairs(vim.fn.split(v, "\\zs")) do
        local candidate = out .. ch
        if display_width(candidate) > target then
          break
        end
        out = candidate
      end
      return out .. suffix
    end

    s = truncate_display(s, width)
    local pad = width - display_width(s)
    if pad > 0 then
      s = s .. string.rep(" ", pad)
    end
    return s
  end

  local type_w = 10
  local key_w = 14
  local status_w = 16
  local assignee_w = 18
  local title_w = 52

  local function format_row(issue_type, key, status, assignee, title)
    return table.concat({
      fixed_width(issue_type, type_w),
      fixed_width(key, key_w),
      fixed_width(status, status_w),
      fixed_width(assignee, assignee_w),
      fixed_width(title, title_w),
    }, "  ")
  end

  local lines = {}
  table.insert(lines, string.format("Project: %s [%s]", clean_jira_text(project_name), clean_jira_text(project_key)))
  table.insert(lines, string.format("Board: %s", clean_jira_text(board_name)))
  table.insert(lines, string.format("Sprint: %s [state:%s]", clean_jira_text(sprint.name), clean_jira_text(sprint.state)))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")
  table.insert(lines, "Tickets:")
  local header = format_row("TYPE", "KEY", "STATUS", "ASSIGNEE", "TITLE")
  table.insert(lines, header)
  table.insert(lines, string.rep("-", #header))

  if #tickets == 0 then
    table.insert(lines, "(none)")
    return table.concat(lines, "\n")
  end

  table.sort(tickets, function(a, b) return a.key < b.key end)
  for _, ticket in ipairs(tickets) do
    table.insert(lines, format_row(ticket.issue_type, ticket.key, ticket.status, ticket.assignee, ticket.summary))
  end

  return table.concat(lines, "\n")
end

local function extract_issue_type(item)
  item = extract_workitem_object(item) or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  local issue_type_val = fields.issuetype
    or fields.issueType
    or item.issuetype
    or item.issueType
    or find_field_value(item, { "issue type", "issuetype", "issue_type" }, true)

  local issue_type = value_to_text(issue_type_val) or "-"
  return clean_jira_text(issue_type)
end

local function trim_text_for_prompt(text, max_len)
  local t = normalize_multiline_text(text, "-")
  max_len = tonumber(max_len) or 0
  if max_len > 0 and #t > max_len then
    t = t:sub(1, max_len) .. "..."
  end
  return t
end

local function build_story_readiness_input(item, fallback)
  item = extract_workitem_object(item) or {}
  fallback = fallback or {}
  local fields = type(item.fields) == "table" and item.fields or {}

  local key = clean_jira_text(value_to_text(item.key) or value_to_text(fields.key) or fallback.key or "")
  local summary = clean_jira_text(value_to_text(item.summary) or value_to_text(fields.summary) or fallback.summary or "(no summary)")
  local status = clean_jira_text(
    value_to_text(fields.status)
      or value_to_text(find_field_value(item, { "status" }, false))
      or fallback.status
      or "-"
  )
  local assignee = clean_jira_text(
    value_to_text(fields.assignee)
      or value_to_text(find_field_value(item, { "assignee" }, false))
      or fallback.assignee
      or "-"
  )
  local story_points = clean_jira_text(value_to_text(extract_story_points(item)) or fallback.story_points or "-")
  local dod = trim_text_for_prompt(extract_definition_of_done(item), 3000)
  local description = trim_text_for_prompt(
    fields.description or find_field_value(item, { "description" }, false) or fallback.description or "-",
    5000
  )

  return {
    key = key,
    summary = summary,
    status = status,
    assignee = assignee,
    story_points = story_points,
    definition_of_done = dod,
    description = description,
  }
end

local function build_story_readiness_batches(stories)
  local max_items = tonumber(vim.g.jira_sprint_ready_batch_items) or 25
  local max_chars = tonumber(vim.g.jira_sprint_ready_batch_chars) or 50000
  if max_items < 1 then
    max_items = 1
  end
  if max_chars < 5000 then
    max_chars = 5000
  end

  local batches = {}
  local current = {}
  local current_chars = 2

  local function flush()
    if #current > 0 then
      table.insert(batches, current)
      current = {}
      current_chars = 2
    end
  end

  for _, story in ipairs(stories) do
    local encoded = encode_json(story)
    local story_chars = #tostring(encoded) + 2
    if #current > 0 and (#current >= max_items or (current_chars + story_chars) > max_chars) then
      flush()
    end
    table.insert(current, story)
    current_chars = current_chars + story_chars
  end
  flush()

  return batches
end

local function extract_json_payload_from_text(text)
  if type(text) ~= "string" or text == "" then
    return nil
  end

  local direct = decode_json(text)
  if direct then
    return direct
  end

  local fenced = text:match("```json%s*(.-)%s*```") or text:match("```%s*(.-)%s*```")
  if fenced then
    local decoded_fenced = decode_json(fenced)
    if decoded_fenced then
      return decoded_fenced
    end
  end

  local first_obj = text:find("{", 1, true)
  local last_obj = nil
  for i = #text, 1, -1 do
    if text:sub(i, i) == "}" then
      last_obj = i
      break
    end
  end
  if first_obj and last_obj and last_obj > first_obj then
    local candidate = text:sub(first_obj, last_obj)
    local decoded_obj = decode_json(candidate)
    if decoded_obj then
      return decoded_obj
    end
  end

  local first_arr = text:find("%[")
  local last_arr = nil
  for i = #text, 1, -1 do
    if text:sub(i, i) == "]" then
      last_arr = i
      break
    end
  end
  if first_arr and last_arr and last_arr > first_arr then
    local candidate = text:sub(first_arr, last_arr)
    local decoded_arr = decode_json(candidate)
    if decoded_arr then
      return decoded_arr
    end
  end

  return nil
end

local function normalize_readiness_status(status, notes)
  local s = string.lower(clean_jira_text(status or ""))
  if s:find("ready", 1, true)
    and not s:find("notready", 1, true)
    and not s:find("not ready", 1, true)
    and not s:find("not_ready", 1, true)
    and not s:find("needs", 1, true) then
    return "sprint ready", clean_jira_text(notes or "")
  end
  if s == "ok" or s == "pass" then
    return "sprint ready", clean_jira_text(notes or "")
  end
  return "needs improvement", clean_jira_text(notes or "")
end

local function format_sprint_backlog_readiness_report(project_key, project_name, board_name, sprint, stories, verdict_by_key, batch_count)
  local lines = {}
  local ready_count = 0
  local improve_count = 0

  table.insert(lines, string.format("Project: %s [%s]", clean_jira_text(project_name), clean_jira_text(project_key)))
  table.insert(lines, string.format("Board: %s", clean_jira_text(board_name)))
  table.insert(lines, string.format("Sprint: %s [state:%s]", clean_jira_text(sprint.name), clean_jira_text(sprint.state)))
  table.insert(lines, string.format("Stories analyzed: %d", #stories))
  table.insert(lines, string.format("OpenAI batches: %d", tonumber(batch_count) or 0))
  table.insert(lines, string.format("Generated: %s", os.date("%Y-%m-%d %H:%M:%S")))
  table.insert(lines, "")
  table.insert(lines, "Sprint Readiness:")

  for _, story in ipairs(stories) do
    local key = clean_jira_text(story.key)
    local verdict = verdict_by_key[key] or {}
    local status = verdict.status or "needs improvement"
    local notes = verdict.notes or "No result returned by model."

    if status == "sprint ready" then
      ready_count = ready_count + 1
      table.insert(lines, string.format("- %s: sprint ready", key))
    else
      improve_count = improve_count + 1
      table.insert(lines, string.format("- %s: needs improvement - %s", key, clean_jira_text(notes)))
    end
  end

  table.insert(lines, "")
  table.insert(lines, string.format("Summary: %d sprint ready, %d need improvements", ready_count, improve_count))
  return table.concat(lines, "\n")
end

local function analyze_story_batches_with_openai(story_batches, on_done)
  local api_key = vim.env.OPENAI_API_KEY
  if type(api_key) ~= "string" or api_key == "" then
    vim.notify("OPENAI_API_KEY is not set", vim.log.levels.ERROR)
    on_done({})
    return
  end

  local all_items = {}
  local total_batches = #story_batches
  local batch_idx = 1

  local function push_items_from_decoded(decoded, fallback_batch_idx)
    local items = nil
    if type(decoded) == "table" then
      if vim.tbl_islist(decoded) then
        items = decoded
      elseif vim.tbl_islist(decoded.items) then
        items = decoded.items
      elseif vim.tbl_islist(decoded.results) then
        items = decoded.results
      end
    end

    if type(items) ~= "table" then
      return false
    end

    for _, raw in ipairs(items) do
      if type(raw) == "table" then
        local key = clean_jira_text(value_to_text(raw.key) or value_to_text(raw.ticket) or "")
        if key ~= "" then
          local status, notes = normalize_readiness_status(
            value_to_text(raw.status) or value_to_text(raw.readiness) or value_to_text(raw.result),
            value_to_text(raw.notes) or value_to_text(raw.reason) or value_to_text(raw.improvement)
          )
          table.insert(all_items, {
            key = key,
            status = status,
            notes = notes ~= "" and notes or ("No notes returned (batch " .. tostring(fallback_batch_idx) .. ")."),
          })
        end
      end
    end
    return true
  end

  local function run_next_batch()
    if batch_idx > total_batches then
      spinner_stop()
      on_done(all_items)
      return
    end

    local batch = story_batches[batch_idx]
    local req = {
      model = vim.g.openai_model or "gpt-4.1-mini",
      temperature = 0.1,
      max_output_tokens = math.min(2500, math.max(600, #batch * 120)),
      input = {
        {
          role = "system",
          content = table.concat({
            "You are a strict agile sprint readiness reviewer.",
            "Assess each story independently.",
            "A story is sprint ready only when all three are present and good quality:",
            "1) Story points are present and sensible.",
            "2) Description is present and specific enough to implement.",
            "3) Definition of Done is present and verifiable.",
            "Return JSON only.",
          }, "\n"),
        },
        {
          role = "user",
          content = table.concat({
            "Evaluate each story and return exactly this JSON schema:",
            '{"items":[{"key":"ABC-1","status":"sprint ready|needs improvement","notes":"short compact note"}]}',
            "notes must be compact (max 140 chars).",
            "If sprint ready, notes can be empty.",
            "",
            "STORIES_JSON_START",
            encode_json(batch),
            "STORIES_JSON_END",
          }, "\n"),
        },
      },
    }

    local req_json = encode_json(req)
    if req_json == "<json encode failed>" then
      spinner_stop()
      vim.notify("Failed to encode OpenAI request JSON", vim.log.levels.ERROR)
      on_done(all_items)
      return
    end

    local req_path = vim.fn.tempname() .. "_openai_sprint_ready_req.json"
    local write_ok = pcall(vim.fn.writefile, { req_json }, req_path)
    if not write_ok then
      spinner_stop()
      vim.notify("Failed to write temporary OpenAI request file", vim.log.levels.ERROR)
      on_done(all_items)
      return
    end

    spinner_start(string.format("OpenAI: sprint readiness batch %d/%d ...", batch_idx, total_batches))
    run_cmd_async(
      {
        "curl",
        "-sS",
        "-X", "POST",
        "https://api.openai.com/v1/responses",
        "-H", "Authorization: Bearer " .. api_key,
        "-H", "Content-Type: application/json",
        "--data-binary", "@" .. req_path,
      },
      function(openai_output, openai_code)
        pcall(vim.fn.delete, req_path)
        if openai_code ~= 0 then
          spinner_stop()
          vim.notify(string.format("OpenAI request failed for batch %d/%d:\n%s", batch_idx, total_batches, openai_output), vim.log.levels.ERROR)
          on_done(all_items)
          return
        end

        local decoded = decode_json(openai_output)
        if not decoded then
          spinner_stop()
          vim.notify("Could not parse OpenAI response JSON", vim.log.levels.ERROR)
          on_done(all_items)
          return
        end

        local api_err = extract_openai_error_message(decoded)
        if api_err then
          spinner_stop()
          vim.notify("OpenAI API error: " .. api_err, vim.log.levels.ERROR)
          on_done(all_items)
          return
        end

        local output_text = extract_openai_output_text(decoded)
        if not output_text or output_text == "" then
          spinner_stop()
          jira_debug_log(
            "jira_sprint_backlog_readiness:openai-response-missing-text:batch-" .. tostring(batch_idx),
            { "curl", "https://api.openai.com/v1/responses" },
            openai_output
          )
          vim.notify("OpenAI response had no readable text. Raw response saved to debug log.", vim.log.levels.ERROR)
          on_done(all_items)
          return
        end

        local parsed_payload = extract_json_payload_from_text(output_text)
        local parsed_ok = push_items_from_decoded(parsed_payload, batch_idx)
        if not parsed_ok then
          jira_debug_log(
            "jira_sprint_backlog_readiness:openai-batch-json-parse-failed:batch-" .. tostring(batch_idx),
            { "curl", "https://api.openai.com/v1/responses" },
            output_text
          )
        end

        batch_idx = batch_idx + 1
        run_next_batch()
      end
    )
  end

  if total_batches == 0 then
    on_done({})
    return
  end

  vim.notify(
    string.format("OpenAI sprint readiness: %d batch(es)", total_batches),
    vim.log.levels.INFO
  )
  run_next_batch()
end

local function jira_sprint_backlog_readiness_for_board(project_key, project_name, board_id, board_name)
  spinner_start("Jira: loading sprints ...")
  local sprint_list_cmd = {
    "acli", "jira", "board", "list-sprints",
    "--id", tostring(board_id),
    "--state", "active,future,closed",
    "--paginate",
    "--json",
  }
  run_cmd_async(sprint_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_sprint_backlog_readiness:list-sprints:command-failed", sprint_list_cmd, output)
      vim.notify("Failed to load sprints:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local sprint_rows = decode_list_output(output, extract_sprints)
    if not sprint_rows then
      spinner_stop()
      jira_debug_log("jira_sprint_backlog_readiness:list-sprints:json-parse-failed", sprint_list_cmd, output)
      vim.notify("Could not parse sprint list JSON output", vim.log.levels.ERROR)
      return
    end

    local sprints = {}
    local entries = {}
    local sprint_by_entry = {}
    for _, raw in ipairs(sprint_rows) do
      local sprint = extract_sprint_info(raw)
      if sprint then
        table.insert(sprints, sprint)
      end
    end

    table.sort(sprints, function(a, b)
      local as = string.lower(a.state or "")
      local bs = string.lower(b.state or "")
      local state_rank = { active = 1, future = 2, closed = 3 }
      local ar = state_rank[as] or 4
      local br = state_rank[bs] or 4
      if ar ~= br then
        return ar < br
      end
      if a.sprint_number and b.sprint_number and a.sprint_number ~= b.sprint_number then
        return a.sprint_number > b.sprint_number
      end
      return tostring(a.name) < tostring(b.name)
    end)

    for _, sprint in ipairs(sprints) do
      local entry = string.format(
        "%s | %s [state:%s]",
        tostring(sprint.id),
        clean_jira_text(sprint.name),
        clean_jira_text(sprint.state)
      )
      table.insert(entries, entry)
      sprint_by_entry[entry] = sprint
    end

    spinner_stop()
    if #entries == 0 then
      vim.notify("No sprints found for board " .. board_name, vim.log.levels.INFO)
      return
    end

    fzf.fzf_exec(entries, {
      prompt = "Jira Sprint Backlog> ",
      previewer = false,
      fzf_opts = { ["--ansi"] = false },
      actions = {
        ['default'] = function(selected)
          local entry = selected and selected[1]
          local sprint = entry and sprint_by_entry[entry] or nil
          if not sprint then
            return
          end

          spinner_start("Jira: loading sprint backlog stories ...")
          local sprint_issue_cmd = {
            "acli", "jira", "sprint", "list-workitems",
            "--board", tostring(board_id),
            "--sprint", tostring(sprint.id),
            "--fields", "key,summary,status,assignee,issuetype",
            "--paginate",
            "--json",
          }
          run_cmd_async(sprint_issue_cmd, function(issue_output, issue_code)
            if issue_code ~= 0 then
              spinner_stop()
              jira_debug_log("jira_sprint_backlog_readiness:list-workitems:command-failed:sprint-" .. tostring(sprint.id), sprint_issue_cmd, issue_output)
              vim.notify("Failed to load sprint work items:\n" .. issue_output, vim.log.levels.ERROR)
              return
            end

            local issue_rows = decode_list_output(issue_output, extract_workitems)
            if not issue_rows then
              spinner_stop()
              jira_debug_log("jira_sprint_backlog_readiness:list-workitems:json-parse-failed:sprint-" .. tostring(sprint.id), sprint_issue_cmd, issue_output)
              vim.notify("Could not parse sprint work items JSON output", vim.log.levels.ERROR)
              return
            end

            local stories = {}
            for _, item in ipairs(issue_rows) do
              local key, summary = extract_key_summary(item)
              if key then
                local issue_type = string.lower(extract_issue_type(item) or "")
                if issue_type:find("story", 1, true) then
                  local status, assignee = extract_status_assignee_parent(item)
                  table.insert(stories, {
                    key = clean_jira_text(key),
                    summary = clean_jira_text(summary),
                    status = clean_jira_text(status),
                    assignee = clean_jira_text(assignee),
                  })
                end
              end
            end

            if #stories == 0 then
              spinner_stop()
              vim.notify("No stories found in selected sprint backlog", vim.log.levels.INFO)
              return
            end

            local by_key = {}
            for _, s in ipairs(stories) do
              by_key[s.key] = s
            end

            local details = {}
            local completed = 0
            local active = 0
            local next_idx = 1
            local max_concurrency = tonumber(vim.g.jira_sprint_ready_fetch_concurrency) or 6
            if max_concurrency < 1 then
              max_concurrency = 1
            end

            local function maybe_finish()
              if next_idx > #stories and active == 0 then
                local ordered_story_inputs = {}
                for _, story in ipairs(stories) do
                  local input = details[story.key] or build_story_readiness_input(nil, story)
                  table.insert(ordered_story_inputs, input)
                end

                local batches = build_story_readiness_batches(ordered_story_inputs)
                analyze_story_batches_with_openai(batches, function(verdict_items)
                  local verdict_by_key = {}
                  for _, v in ipairs(verdict_items or {}) do
                    if type(v) == "table" and type(v.key) == "string" and v.key ~= "" then
                      verdict_by_key[clean_jira_text(v.key)] = {
                        status = v.status,
                        notes = v.notes,
                      }
                    end
                  end

                  local report = format_sprint_backlog_readiness_report(
                    project_key,
                    project_name,
                    board_name,
                    sprint,
                    ordered_story_inputs,
                    verdict_by_key,
                    #batches
                  )
                  insert_block_at_cursor(report)
                end)
              end
            end

            local function pump_details()
              while active < max_concurrency and next_idx <= #stories do
                local idx = next_idx
                next_idx = next_idx + 1
                active = active + 1

                local key = stories[idx].key
                spinner.msg = string.format("Jira: loading story details %d/%d ...", completed, #stories)
                run_cmd_async(
                  { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
                  function(detail_output, detail_code)
                    active = active - 1
                    completed = completed + 1
                    spinner.msg = string.format("Jira: loading story details %d/%d ...", completed, #stories)

                    if detail_code == 0 then
                      local decoded = decode_json(detail_output)
                      if decoded then
                        details[key] = build_story_readiness_input(decoded, by_key[key])
                      else
                        jira_debug_log(
                          "jira_sprint_backlog_readiness:story-view:json-parse-failed:" .. key,
                          { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
                          detail_output
                        )
                        details[key] = build_story_readiness_input(nil, by_key[key])
                      end
                    else
                      jira_debug_log(
                        "jira_sprint_backlog_readiness:story-view:command-failed:" .. key,
                        { "acli", "jira", "workitem", "view", key, "--fields", "*all", "--json" },
                        detail_output
                      )
                      details[key] = build_story_readiness_input(nil, by_key[key])
                    end

                    maybe_finish()
                    pump_details()
                  end
                )
              end
            end

            pump_details()
          end)
        end,
      },
    })
  end)
end

local function jira_sprint_tickets_for_board(project_key, project_name, board_id, board_name)
  spinner_start("Jira: loading sprints ...")
  local sprint_list_cmd = {
    "acli", "jira", "board", "list-sprints",
    "--id", tostring(board_id),
    "--state", "active,future,closed",
    "--paginate",
    "--json",
  }
  run_cmd_async(sprint_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_sprint_tickets:list-sprints:command-failed", sprint_list_cmd, output)
      vim.notify("Failed to load sprints:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local sprint_rows = decode_list_output(output, extract_sprints)
    if not sprint_rows then
      spinner_stop()
      jira_debug_log("jira_sprint_tickets:list-sprints:json-parse-failed", sprint_list_cmd, output)
      vim.notify("Could not parse sprint list JSON output", vim.log.levels.ERROR)
      return
    end

    local sprints = {}
    local entries = {}
    local sprint_by_entry = {}
    for _, raw in ipairs(sprint_rows) do
      local sprint = extract_sprint_info(raw)
      if sprint then
        table.insert(sprints, sprint)
      end
    end

    table.sort(sprints, function(a, b)
      local as = string.lower(a.state or "")
      local bs = string.lower(b.state or "")
      local state_rank = { active = 1, future = 2, closed = 3 }
      local ar = state_rank[as] or 4
      local br = state_rank[bs] or 4
      if ar ~= br then
        return ar < br
      end
      if a.sprint_number and b.sprint_number and a.sprint_number ~= b.sprint_number then
        return a.sprint_number > b.sprint_number
      end
      return tostring(a.name) < tostring(b.name)
    end)

    for _, sprint in ipairs(sprints) do
      local entry = string.format(
        "%s | %s [state:%s]",
        tostring(sprint.id),
        clean_jira_text(sprint.name),
        clean_jira_text(sprint.state)
      )
      table.insert(entries, entry)
      sprint_by_entry[entry] = sprint
    end

    spinner_stop()
    if #entries == 0 then
      vim.notify("No sprints found for board " .. board_name, vim.log.levels.INFO)
      return
    end

    fzf.fzf_exec(entries, {
      prompt = "Jira Sprint> ",
      previewer = false,
      fzf_opts = { ["--ansi"] = false },
      actions = {
        ['default'] = function(selected)
          local entry = selected and selected[1]
          local sprint = entry and sprint_by_entry[entry] or nil
          if not sprint then
            return
          end

          spinner_start("Jira: loading sprint tickets ...")
          local sprint_issue_cmd = {
            "acli", "jira", "sprint", "list-workitems",
            "--board", tostring(board_id),
            "--sprint", tostring(sprint.id),
            "--fields", "key,summary,status,assignee,issuetype",
            "--paginate",
            "--json",
          }
          run_cmd_async(sprint_issue_cmd, function(issue_output, issue_code)
            if issue_code ~= 0 then
              spinner_stop()
              jira_debug_log("jira_sprint_tickets:list-workitems:command-failed:sprint-" .. tostring(sprint.id), sprint_issue_cmd, issue_output)
              vim.notify("Failed to load sprint work items:\n" .. issue_output, vim.log.levels.ERROR)
              return
            end

            local issue_rows = decode_list_output(issue_output, extract_workitems)
            if not issue_rows then
              spinner_stop()
              jira_debug_log("jira_sprint_tickets:list-workitems:json-parse-failed:sprint-" .. tostring(sprint.id), sprint_issue_cmd, issue_output)
              vim.notify("Could not parse sprint work items JSON output", vim.log.levels.ERROR)
              return
            end

            local tickets = {}
            for _, item in ipairs(issue_rows) do
              local key, summary = extract_key_summary(item)
              if key then
                local status, assignee = extract_status_assignee_parent(item)
                table.insert(tickets, {
                  key = clean_jira_text(key),
                  summary = clean_jira_text(summary),
                  status = clean_jira_text(status),
                  assignee = clean_jira_text(assignee),
                  issue_type = extract_issue_type(item),
                })
              end
            end

            spinner_stop()
            insert_block_at_cursor(build_sprint_tickets_report(project_key, project_name, board_name, sprint, tickets))
          end)
        end,
      },
    })
  end)
end

local function jira_sprint_tickets(opts)
  opts = opts or {}
  spinner_start("Jira: loading projects ...")
  local project_list_cmd = { "acli", "jira", "project", "list", "--paginate", "--json" }
  run_cmd_async(project_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_sprint_tickets:project-list:command-failed", project_list_cmd, output)
      vim.notify("Failed to load Jira projects:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      spinner_stop()
      jira_debug_log("jira_sprint_tickets:project-list:json-parse-failed", project_list_cmd, output)
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

          local function open_board_picker(board_rows)
            local board_entries = {}
            local board_by_entry = {}
            for _, board in ipairs(board_rows) do
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
              jira_sprint_tickets_for_board(project.key, project.name, b.id, b.name)
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
                    jira_sprint_tickets_for_board(project.key, project.name, board.id, board.name)
                  end
                end,
              },
            })
          end

          spinner_start("Jira: loading boards ...")
          local board_search_cmd = { "acli", "jira", "board", "search", "--project", project.key, "--type", "scrum", "--paginate", "--json" }
          run_cmd_async(board_search_cmd, function(board_output, board_code)
            if board_code ~= 0 then
              spinner_stop()
              jira_debug_log("jira_sprint_tickets:board-search:command-failed", board_search_cmd, board_output)
              vim.notify("Failed to load boards:\n" .. board_output, vim.log.levels.ERROR)
              return
            end

            local board_rows = decode_list_output(board_output, extract_boards)
            if not board_rows then
              spinner_stop()
              jira_debug_log("jira_sprint_tickets:board-search:json-parse-failed", board_search_cmd, board_output)
              vim.notify("Could not parse board search JSON output", vim.log.levels.ERROR)
              return
            end

            if #board_rows > 0 then
              open_board_picker(board_rows)
              return
            end

            local board_search_all_cmd = { "acli", "jira", "board", "search", "--type", "scrum", "--paginate", "--json" }
            run_cmd_async(board_search_all_cmd, function(all_output, all_code)
              if all_code ~= 0 then
                spinner_stop()
                jira_debug_log("jira_sprint_tickets:board-search-fallback:command-failed", board_search_all_cmd, all_output)
                vim.notify("No project-scoped boards found, and fallback board search failed", vim.log.levels.ERROR)
                return
              end

              local all_rows = decode_list_output(all_output, extract_boards)
              if not all_rows then
                spinner_stop()
                jira_debug_log("jira_sprint_tickets:board-search-fallback:json-parse-failed", board_search_all_cmd, all_output)
                vim.notify("Could not parse fallback board search JSON output", vim.log.levels.ERROR)
                return
              end

              vim.notify(
                "No project-scoped boards found; showing all scrum boards as fallback",
                vim.log.levels.WARN
              )
              open_board_picker(all_rows)
            end)
          end)
        end,
      },
    })
  end)
end

local function jira_sprint_backlog_readiness(opts)
  opts = opts or {}
  spinner_start("Jira: loading projects ...")
  local project_list_cmd = { "acli", "jira", "project", "list", "--paginate", "--json" }
  run_cmd_async(project_list_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_sprint_backlog_readiness:project-list:command-failed", project_list_cmd, output)
      vim.notify("Failed to load Jira projects:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local decoded = decode_json(output)
    if not decoded then
      spinner_stop()
      jira_debug_log("jira_sprint_backlog_readiness:project-list:json-parse-failed", project_list_cmd, output)
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

          local function open_board_picker(board_rows)
            local board_entries = {}
            local board_by_entry = {}
            for _, board in ipairs(board_rows) do
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
              jira_sprint_backlog_readiness_for_board(project.key, project.name, b.id, b.name)
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
                    jira_sprint_backlog_readiness_for_board(project.key, project.name, board.id, board.name)
                  end
                end,
              },
            })
          end

          spinner_start("Jira: loading boards ...")
          local board_search_cmd = { "acli", "jira", "board", "search", "--project", project.key, "--type", "scrum", "--paginate", "--json" }
          run_cmd_async(board_search_cmd, function(board_output, board_code)
            if board_code ~= 0 then
              spinner_stop()
              jira_debug_log("jira_sprint_backlog_readiness:board-search:command-failed", board_search_cmd, board_output)
              vim.notify("Failed to load boards:\n" .. board_output, vim.log.levels.ERROR)
              return
            end

            local board_rows = decode_list_output(board_output, extract_boards)
            if not board_rows then
              spinner_stop()
              jira_debug_log("jira_sprint_backlog_readiness:board-search:json-parse-failed", board_search_cmd, board_output)
              vim.notify("Could not parse board search JSON output", vim.log.levels.ERROR)
              return
            end

            if #board_rows > 0 then
              open_board_picker(board_rows)
              return
            end

            local board_search_all_cmd = { "acli", "jira", "board", "search", "--type", "scrum", "--paginate", "--json" }
            run_cmd_async(board_search_all_cmd, function(all_output, all_code)
              if all_code ~= 0 then
                spinner_stop()
                jira_debug_log("jira_sprint_backlog_readiness:board-search-fallback:command-failed", board_search_all_cmd, all_output)
                vim.notify("No project-scoped boards found, and fallback board search failed", vim.log.levels.ERROR)
                return
              end

              local all_rows = decode_list_output(all_output, extract_boards)
              if not all_rows then
                spinner_stop()
                jira_debug_log("jira_sprint_backlog_readiness:board-search-fallback:json-parse-failed", board_search_all_cmd, all_output)
                vim.notify("Could not parse fallback board search JSON output", vim.log.levels.ERROR)
                return
              end

              vim.notify(
                "No project-scoped boards found; showing all scrum boards as fallback",
                vim.log.levels.WARN
              )
              open_board_picker(all_rows)
            end)
          end)
        end,
      },
    })
  end)
end

local function jira_current_sprint_assignee_overview(opts)
  opts = opts or {}
  spinner_start("Jira: loading boards ...")
  local board_search_cmd = { "acli", "jira", "board", "search", "--type", "scrum", "--paginate", "--json" }
  run_cmd_async(board_search_cmd, function(output, code)
    if code ~= 0 then
      spinner_stop()
      jira_debug_log("jira_current_sprint_assignee_overview:board-search:command-failed", board_search_cmd, output)
      vim.notify("Failed to load Jira boards:\n" .. output, vim.log.levels.ERROR)
      return
    end

    local board_rows = decode_list_output(output, extract_boards)
    if not board_rows then
      spinner_stop()
      jira_debug_log("jira_current_sprint_assignee_overview:board-search:json-parse-failed", board_search_cmd, output)
      vim.notify("Could not parse board search JSON output", vim.log.levels.ERROR)
      return
    end

    local board_entries = {}
    local board_by_entry = {}
    for _, board in ipairs(board_rows) do
      local board_id, board_name = extract_board_id_name(board)
      if board_id then
        local project_key, project_name = extract_board_project_key_name(board)
        local entry = string.format(
          "%s | %s [%s]",
          tostring(board_id),
          clean_jira_text(board_name),
          clean_jira_text(project_key)
        )
        table.insert(board_entries, entry)
        board_by_entry[entry] = {
          id = board_id,
          name = board_name,
          project_key = project_key,
          project_name = project_name,
        }
      end
    end

    spinner_stop()
    if #board_entries == 0 then
      vim.notify("No scrum boards found", vim.log.levels.INFO)
      return
    end

    if #board_entries == 1 then
      local b = board_by_entry[board_entries[1]]
      jira_current_sprint_assignee_overview_for_board(b.project_key, b.project_name, b.id, b.name)
      return
    end

    table.sort(board_entries)
    fzf.fzf_exec(board_entries, {
      prompt = "Jira Board> ",
      previewer = false,
      fzf_opts = { ["--ansi"] = false },
      actions = {
        ['default'] = function(selected)
          local entry = selected and selected[1]
          local board = entry and board_by_entry[entry] or nil
          if not board then
            return
          end
          jira_current_sprint_assignee_overview_for_board(
            board.project_key,
            board.project_name,
            board.id,
            board.name
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
require('fzf-lua').afas_projects = afas_projects
require('fzf-lua').jira_project_epics_stories = jira_project_epics_stories
require('fzf-lua').jira_project_sprints = jira_project_sprints
require('fzf-lua').jira_sprint_tickets = jira_sprint_tickets
require('fzf-lua').jira_sprint_backlog_readiness = jira_sprint_backlog_readiness
require('fzf-lua').jira_current_sprint_assignee_overview = jira_current_sprint_assignee_overview
require('fzf-lua').jira_preview_ticket = jira_preview_ticket
require('fzf-lua').jira_open_ticket = jira_open_ticket
require('fzf-lua').jira_summarize_ticket_progress = jira_summarize_ticket_progress
require('fzf-lua').openai_current_buffer_prompt = openai_current_buffer_prompt
require('fzf-lua').jira_sprint_retro_presentation = jira_sprint_retro_presentation

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

vim.api.nvim_create_user_command("VimwikiSearchAll", function(opts)
  require('fzf-lua').vimwiki_grep({ search = opts.args })
end, {
  nargs = "*",
  desc = "Search across all Vimwiki files with fzf-lua",
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

vim.api.nvim_create_user_command("AfasProjects", function(opts)
  require('fzf-lua').afas_projects({ query = opts.args })
end, {
  nargs = "*",
  desc = "afas_projects: Fetch AFAS Profit projects via REST API and pick a project name",
})

vim.api.nvim_create_user_command("JiraProjectEpicsStories", function(opts)
  require('fzf-lua').jira_project_epics_stories({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_project_epics_stories: Pick project, dump epics/stories including Done by default",
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

vim.api.nvim_create_user_command("JiraSprintTickets", function(opts)
  require('fzf-lua').jira_sprint_tickets({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_sprint_tickets: Pick project/board/sprint, then dump tickets for that sprint",
})

vim.api.nvim_create_user_command("JiraSprintBacklogReadiness", function(opts)
  require('fzf-lua').jira_sprint_backlog_readiness({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_sprint_backlog_readiness: Pick sprint backlog stories and evaluate sprint readiness with OpenAI",
})

vim.api.nvim_create_user_command("JiraCurrentSprintAssigneeOverview", function(opts)
  require('fzf-lua').jira_current_sprint_assignee_overview({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_current_sprint_assignee_overview: Pick assignee and insert active sprint workload overview",
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

vim.api.nvim_create_user_command("JiraSummarizeTicketProgress", function(opts)
  require('fzf-lua').jira_summarize_ticket_progress({ args = opts.args })
end, {
  nargs = "*",
  desc = "jira_summarize_ticket_progress: Summarize progress with OpenAI and insert into current buffer",
})

vim.api.nvim_create_user_command("JiraSprintRetroPresentation", function(opts)
  require('fzf-lua').jira_sprint_retro_presentation({ query = opts.args })
end, {
  nargs = "*",
  desc = "jira_sprint_retro_presentation: Select Jira spaces and generate a LaTeX sprint retrospective deck in a new tab",
})

vim.api.nvim_create_user_command("OpenAIBufferPrompt", function(opts)
  require('fzf-lua').openai_current_buffer_prompt({ args = opts.args })
end, {
  nargs = "*",
  desc = "openai_current_buffer_prompt: Ask OpenAI using current buffer as context and insert output",
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
