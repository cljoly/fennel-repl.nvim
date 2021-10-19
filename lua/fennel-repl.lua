local fennel = require("fennel")
local coro = nil
vim.cmd("\nfunction! FennelReplCallback(text)\n    call luaeval('require(\"fennel-repl\").callback(_A[1], _A[2])', [bufnr(), a:text])\nendfunction")
local function create_window(mods)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_command((mods .. " new"))
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "prompt")
  vim.api.nvim_buf_set_option(bufnr, "filetype", "fennel")
  vim.fn.prompt_setcallback(bufnr, "FennelReplCallback")
  vim.fn.prompt_setprompt(bufnr, ">> ")
  vim.api.nvim_command("startinsert")
  return bufnr
end
local function close(bufnr)
  vim.api.nvim_buf_set_option(bufnr, "buftype", "")
  return vim.api.nvim_buf_set_lines(bufnr, -1, -1, true, {"[Process exited]"})
end
local function read_chunk()
  local input = coroutine.yield(true)
  return (input and (input .. "\n"))
end
local function on_values(vals)
  return coroutine.yield(false, (table.concat(vals, "\9") .. "\n"))
end
local function on_error(errtype, err, lua_source)
  local function _2_()
    local _1_ = errtype
    if (_1_ == "Runtime") then
      return (fennel.traceback(tostring(err), 4) .. "\n")
    else
      local _ = _1_
      return ("%s error: %s\n"):format(errtype, tostring(err))
    end
  end
  return coroutine.yield(false, _2_())
end
local function write(bufnr, ...)
  local text = string.gsub(table.concat({...}, " "), "\\n", "\n")
  local lines = vim.split(text, "\n")
  return vim.api.nvim_buf_set_lines(bufnr, -2, -1, true, lines)
end
local function xpcall_2a(f, err, ...)
  local res = vim.F.pack_len(pcall(f))
  if not res[1] then
    res[2] = err(res[2])
  end
  return vim.F.unpack_len(res)
end
local function callback(bufnr, text)
  local ok_3f, reading_3f, out = coroutine.resume(coro, text)
  if (ok_3f and (coroutine.status(coro) == "suspended")) then
    local function _5_()
      if reading_3f then
        return ".."
      else
        return ">> "
      end
    end
    vim.fn.prompt_setprompt(bufnr, _5_())
    if not reading_3f then
      write(bufnr, out)
      return coroutine.resume(coro)
    end
  else
    return close(bufnr)
  end
end
local function start(_3fmods)
  local bufnr = create_window((_3fmods or ""))
  local env = {}
  local fenv = {}
  for k, v in pairs(getfenv(0)) do
    env[k] = v
    fenv[k] = v
  end
  local function _8_(...)
    return write(bufnr, ..., "\n")
  end
  env["print"] = _8_
  fenv["xpcall"] = xpcall_2a
  local repl = setfenv(fennel.repl, fenv)
  local function _9_()
    return repl({allowedGlobals = false, env = env, onError = on_error, onValues = on_values, readChunk = read_chunk})
  end
  coro = coroutine.create(_9_)
  return coroutine.resume(coro)
end
return {callback = callback, start = start}
