local M = {}

local parser = require("diff_peek.parser")

local function script_dir()
  local source = debug.getinfo(1, "S").source
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return source:match("(.*)/[^/]+$") or "."
end

local function fixture_path(name)
  return script_dir() .. "/fixtures/" .. name
end

local function load_fixture_into_buf(path)
  local lines = vim.fn.readfile(path)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

local failures = {}

local function fail(name, message)
  table.insert(failures, string.format("[%s] %s", name, message))
end

local function assert_eq(name, label, expected, actual)
  if expected ~= actual then
    fail(name, string.format("%s: expected %s, got %s", label, tostring(expected), tostring(actual)))
  end
end

local function check_multi_hunk(name)
  local path = fixture_path("multi_hunk.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local entry_l6 = parser.line_to_location(buf, 6)
  if not entry_l6 then
    fail(name, "line 6 expected mappable context, got nil")
  else
    assert_eq(name, "L6.kind", "context", entry_l6.kind)
    assert_eq(name, "L6.path", "lib/example.rb", entry_l6.path)
    assert_eq(name, "L6.file_line", 10, entry_l6.file_line)
    assert_eq(name, "L6.hunk_id", 1, entry_l6.hunk_id)
  end

  local entry_l8 = parser.line_to_location(buf, 8)
  if not entry_l8 then
    fail(name, "line 8 expected mappable added, got nil")
  else
    assert_eq(name, "L8.kind", "added", entry_l8.kind)
    assert_eq(name, "L8.file_line", 11, entry_l8.file_line)
    assert_eq(name, "L8.hunk_id", 1, entry_l8.hunk_id)
  end

  local entry_l12 = parser.line_to_location(buf, 12)
  if not entry_l12 then
    fail(name, "line 12 expected mappable added, got nil")
  else
    assert_eq(name, "L12.kind", "added", entry_l12.kind)
    assert_eq(name, "L12.file_line", 32, entry_l12.file_line)
    assert_eq(name, "L12.hunk_id", 2, entry_l12.hunk_id)
  end

  local range, reason = parser.selection_to_range(buf, 6, 13)
  assert_eq(name, "cross-hunk reason", "multi_hunk", reason)
  assert_eq(name, "cross-hunk range", nil, range)
end

local function check_rename_100(name)
  local path = fixture_path("rename_100.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local lines = vim.fn.readfile(path)
  for i = 1, #lines do
    local entry = parser.line_to_location(buf, i)
    if entry then
      fail(name, string.format("expected line %d unmappable, got entry %s", i, vim.inspect(entry)))
    end
  end

  local range, reason = parser.selection_to_range(buf, 1, #lines)
  assert_eq(name, "rename reason", "no_mappable", reason)
  assert_eq(name, "rename range", nil, range)
end

local function check_binary(name)
  local path = fixture_path("binary.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local lines = vim.fn.readfile(path)
  for i = 1, #lines do
    local entry = parser.line_to_location(buf, i)
    if entry then
      fail(name, string.format("expected line %d unmappable, got entry %s", i, vim.inspect(entry)))
    end
  end

  local range, reason = parser.selection_to_range(buf, 3, 3)
  assert_eq(name, "binary banner reason", "no_mappable", reason)
  assert_eq(name, "binary banner range", nil, range)
end

local function check_untracked(name)
  local path = fixture_path("untracked.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local entry_l7 = parser.line_to_location(buf, 7)
  if not entry_l7 then
    fail(name, "line 7 expected mappable added, got nil")
  else
    assert_eq(name, "L7.path", "notes.md", entry_l7.path)
    assert_eq(name, "L7.kind", "added", entry_l7.kind)
    assert_eq(name, "L7.file_line", 1, entry_l7.file_line)
  end

  local entry_l9 = parser.line_to_location(buf, 9)
  if not entry_l9 then
    fail(name, "line 9 expected mappable added, got nil")
  else
    assert_eq(name, "L9.file_line", 3, entry_l9.file_line)
  end

  local range, reason = parser.selection_to_range(buf, 7, 9)
  if reason then
    fail(name, "expected range, got reason " .. tostring(reason))
  end
  if range then
    assert_eq(name, "range.start_file_line", 1, range.start_file_line)
    assert_eq(name, "range.end_file_line", 3, range.end_file_line)
    assert_eq(name, "range.path", "notes.md", range.path)
  end
end

local function check_hunk_no_count(name)
  local path = fixture_path("hunk_no_count.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local entry_l6 = parser.line_to_location(buf, 6)
  if not entry_l6 then
    fail(name, "line 6 expected mappable removed, got nil")
  else
    assert_eq(name, "L6.kind", "removed", entry_l6.kind)
    assert_eq(name, "L6.file_line", nil, entry_l6.file_line)
  end

  local entry_l7 = parser.line_to_location(buf, 7)
  if not entry_l7 then
    fail(name, "line 7 expected mappable added, got nil")
  else
    assert_eq(name, "L7.kind", "added", entry_l7.kind)
    assert_eq(name, "L7.file_line", 10, entry_l7.file_line)
  end
end

local function check_removed_only(name)
  local path = fixture_path("removed_only.diff")
  local buf = load_fixture_into_buf(path)
  parser._clear_cache_for_tests()
  parser.attach(buf)

  local entry_l7 = parser.line_to_location(buf, 7)
  if not entry_l7 then
    fail(name, "line 7 expected mappable removed, got nil")
  else
    assert_eq(name, "L7.kind", "removed", entry_l7.kind)
    assert_eq(name, "L7.file_line", nil, entry_l7.file_line)
    assert_eq(name, "L7.pre_file_line", 6, entry_l7.pre_file_line)
  end

  local entry_l8 = parser.line_to_location(buf, 8)
  if not entry_l8 then
    fail(name, "line 8 expected mappable removed, got nil")
  else
    assert_eq(name, "L8.pre_file_line", 7, entry_l8.pre_file_line)
  end

  local range, reason = parser.selection_to_range(buf, 7, 8)
  if reason then
    fail(name, "expected range, got reason " .. tostring(reason))
  end
  if range then
    assert_eq(name, "range.path", "sample.txt", range.path)
    assert_eq(name, "range.start_file_line", 6, range.start_file_line)
    assert_eq(name, "range.end_file_line", 7, range.end_file_line)
  end
end

function M.run()
  failures = {}

  check_multi_hunk("multi_hunk")
  check_rename_100("rename_100")
  check_binary("binary")
  check_untracked("untracked")
  check_hunk_no_count("hunk_no_count")
  check_removed_only("removed_only")

  if #failures == 0 then
    io.stdout:write("parser_test: all assertions passed\n")
    os.exit(0)
  else
    for _, f in ipairs(failures) do
      io.stderr:write(f .. "\n")
    end
    io.stderr:write(string.format("parser_test: %d failure(s)\n", #failures))
    os.exit(1)
  end
end

return M
