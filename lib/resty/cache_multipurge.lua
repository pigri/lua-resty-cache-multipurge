-- vim: set ts=2 sw=2 sts=2 et:
--
--  Original Author: Diego Blanco <diego.blanco@treitos.com>
--  Modified by: David <david@papp.ai>
--  Version: 0.2
--
-- This module provides cache purging functionality for OpenResty
-- It supports purging individual cache entries, multiple entries by URI pattern,
-- and complete cache purging

local md5 = require('md5')
local _M = {}

-- Module-level configuration storage
local cache_paths
local cache_keyfinder
local cache_keyfinder_path
local cache_strip
local cache_key

-- Initialize the module with configuration
-- @param config table Configuration table containing:
--   - cache_key: The cache key pattern
--   - cache_paths: Array of cache paths
--   - cache_keyfinder: Optional path to cache keyfinder binary
--   - cache_keyfinder_path: Optional path to cache keyfinder directory
--   - cache_strip: Optional prefix to strip from URIs
function _M.init(config)
  if not config then
    return nil, "configuration is required"
  end

  if not config.cache_paths or #config.cache_paths == 0 then
    return nil, "cache_paths is required"
  end

  cache_paths = config.cache_paths
  cache_keyfinder = config.cache_keyfinder or 'cache_keyfinder'
  cache_keyfinder_path = config.cache_keyfinder_path or "/usr/local/openresty/bin/"
  cache_strip = config.cache_strip or ""

  return true
end

-- Safely escape shell command parameters
local function safe_shell_command_param(str)
  if not str then return "" end
  return "'"..str:gsub("%'", "'\"'\"'").."'"
end

-- Execute shell command with error handling
local function execute_shell_command(cmd)
  local handle = io.popen(cmd .. " 2>&1")
  if not handle then
    ngx.log(ngx.ERR, "Failed to execute command: ", cmd)
    return nil, "Failed to execute command"
  end

  local result = handle:read("*a")
  local success = handle:close()

  if not success then
    ngx.log(ngx.ERR, "Command failed: ", cmd, " Result: ", result)
    return nil, result
  end

  return true
end

-- Purge all cache entries
local function purge_all()
  for _, cache_path in ipairs(cache_paths) do
    local cmd = "rm -rf '"..cache_path.."'/*"
    local ok, err = execute_shell_command(cmd)
    if not ok then
      ngx.log(ngx.ERR, "Failed to purge cache path: ", cache_path, " Error: ", err)
    end
  end
end

-- Purge multiple cache entries by URI pattern
local function purge_multi(input_uri)
  if not input_uri then
    ngx.log(ngx.ERR, "URI is required for multi-purge")
    return
  end

  if cache_keyfinder == "" or cache_keyfinder == "0" then
    -- ngx.log(ngx.WARN, "You are using grep to find the cache keys. This is not recommended.")
    -- local cache_key_re = cache_key:gsub("([%.%[%]])", "\\%1")
    -- cache_key_re = cache_key_re:gsub(uri:gsub("%p","%%%1"), uri..".*")
    local safe_grep_param = safe_shell_command_param("^KEY: "..input_uri)

    for _, cache_path in ipairs(cache_paths) do
      local cmd = "grep -Raslm1 "..safe_grep_param.." "..cache_path.." | xargs -r rm -f"
      local ok, err = execute_shell_command(cmd)
      if not ok then
        ngx.log(ngx.ERR, "Failed to purge cache path: ", cache_path, " Error: ", err)
      end
    end
  else
    -- local uri_start = cache_key:find(uri, 1, true) or cache_key:len()
    -- local prefix = safe_shell_command_param(cache_key:sub(1, uri_start-1)..uri)
    -- local suffix = " "..safe_shell_command_param(cache_key:sub(uri_start + uri:len()))
    --  local prefix = safe_shell_command_param(cache_key)
    local suffix = " "..safe_shell_command_param(input_uri)

    for _, cache_path in ipairs(cache_paths) do
      local cmd = cache_keyfinder_path .. cache_keyfinder .. " "..cache_path.." "..suffix.." -d"
      ngx.log(ngx.INFO, "Executing command: ", cmd)
      local ok, err = execute_shell_command(cmd)
      if not ok then
        ngx.log(ngx.ERR, "Failed to purge cache path: ", cache_path, " Error: ", err)
      end
    end
  end
end

-- Purge a single cache entry by key
local function purge_one(cache_key_input)
  if not cache_key_input then
    ngx.log(ngx.ERR, "Cache key is required for single purge")
    return
  end

  local cache_key_md5 = md5.sumhexa(cache_key_input)
  for _, cache_path in ipairs(cache_paths) do
    local cmd = "find '"..cache_path.."' -name '"..cache_key_md5.."' -type f -exec rm {} + -quit"
    local ok, err = execute_shell_command(cmd)
    if not ok then
      ngx.log(ngx.ERR, "Failed to purge cache key: ", cache_key_input, " Error: ", err)
    end
  end
end

-- Main purge function
-- @param input_uri string The URI to purge
function _M.purge_cache(input_uri, cache_purge_type)
  if not input_uri then
    ngx.log(ngx.ERR, "Input URI is required")
    return nil, "Input URI is required"
  end

  local uri = input_uri
  if cache_strip and cache_strip ~= "" then
    uri = input_uri:gsub(cache_strip:gsub("%p", "%%%1"), "")
  end

  local cache_key_modified = uri:gsub(input_uri:gsub("%p", "%%%1"), uri)
  ngx.log(ngx.INFO, "Input URI: ", input_uri)
  ngx.log(ngx.INFO, "Cache key modified: ", cache_key_modified)
  ngx.log(ngx.INFO, "SUB URI: ", string.sub(input_uri, -1))

  if string.sub(input_uri, -1) == '*' then
    if cache_purge_type == 'all' then
      purge_all()
    else
      local uri_without_star = string.sub(uri, 1, -2)
      purge_multi(uri_without_star)
    end
  else
    purge_one(cache_key_modified)
  end

  return true
end

return _M
