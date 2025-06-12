# Lua Resty Cache Multipurge (lua)

## Description

Handle **cache purges** in a versatile and easy way. This *lua module* will allow you to request the removal from cache of **one or multiple** urls using a wild card `*` at the end. The module supports both individual cache entry purging and pattern-based purging.


## Requirements

 * Nginx Lua Module
 * MD5 Lua Library

 If you are on Debian/Ubuntu

 ```
 apt install libnginx-mod-http-lua lua-md5
 ```

## Installation

* Install the above requirements
* Copy the `cache_multipurge.lua` file to a path readable by the user that runs *nginx*. (i.e. `/etc/nginx/lua`)
* Make sure the Lua module is in your package path by adding to your nginx.conf:
  ```
  lua_package_path "/etc/nginx/lua/?.lua;;";
  ```

## Configuration

### Available Configuration Options

The module is initialized using a Lua configuration block with the following options:

* `cache_paths`: (**mandatory**) Array of paths where cache files are stored. This should match the paths provided to `proxy_cache_path`, `fastcgi_cache_path`, etc.
* `cache_keyfinder`: (optional) Name of the keyfinder binary for better performance. Defaults to "cache_keyfinder".
* `cache_keyfinder_path`: (optional) Path to the keyfinder binary directory. Defaults to "/usr/local/openresty/bin/".
* `cache_strip`: (optional) Prefix to strip from URIs before purging. Useful if you call the cache purge from a location different than `/`.

### Example 1: Basic Cache Purge Setup

Here's a basic setup that allows cache purging via the PURGE method:

```
# In your nginx.conf
location /cache/purge {
    # Only allow PURGE method
    limit_except PURGE {
        deny all;
    }

    content_by_lua_block {
        local cache_multipurge = require("resty.cache_multipurge")
        local ok, err = cache_multipurge.init({
            cache_paths = {"/tmp/cache"},
            cache_keyfinder = "cache_keyfinder"
        })
        if not ok then
            ngx.log(ngx.ERR, "Failed to initialize cache_multipurge: ", err)
            ngx.exit(500)
        end
        local cache_key = ngx.var.arg_url
        if not cache_key then
            ngx.status = 400
            ngx.say("url parameter is required")
            ngx.exit(400)
        end
        local cache_purge_type = ngx.var.arg_type or nil
        local ok, err = cache_multipurge.purge_cache(cache_key, cache_purge_type)
        if not ok then
            ngx.log(ngx.ERR, "Failed to purge cache: ", err)
            ngx.exit(500)
        end
        ngx.say("Cache purged successfully")
    }
}
```

### Example 2: Using with Proxy Cache

Here's an example of how to use it with a proxy cache setup:

```
# Cache configuration
proxy_cache_path /tmp/cache levels=1:2 keys_zone=cache_zone:10m inactive=60m max_size=100m;

server {
    # ... other server configuration ...

    # Cache purge location
    location /cache/purge {
        limit_except PURGE {
            deny all;
        }

        content_by_lua_block {
            local cache_multipurge = require("resty.cache_multipurge")
            local ok, err = cache_multipurge.init({
                cache_paths = {"/tmp/cache"},
                cache_keyfinder = "cache_keyfinder",
                cache_strip = "/cache/purge"  # Strip this prefix from URLs
            })
            if not ok then
                ngx.log(ngx.ERR, "Failed to initialize cache_multipurge: ", err)
                ngx.exit(500)
            end
            local cache_key = ngx.var.arg_url
            if not cache_key then
                ngx.status = 400
                ngx.say("url parameter is required")
                ngx.exit(400)
            end
            local cache_purge_type = ngx.var.arg_type or nil
            local ok, err = cache_multipurge.purge_cache(cache_key, cache_purge_type)
            if not ok then
                ngx.log(ngx.ERR, "Failed to purge cache: ", err)
                ngx.exit(500)
            end
            ngx.say("Cache purged successfully")
        }
    }

    # Example cached location
    location /cached-content/ {
        proxy_pass http://backend;
        proxy_cache cache_zone;
        proxy_cache_key "$scheme://$host$request_uri$is_args$args";
        # ... other proxy settings ...
    }
}
```

### Usage Examples

After setting up the configuration, you can purge the cache in several ways:

1. Purge a single URL:
   ```
   PURGE /cache/purge?url=/path/to/file.jpg
   ```

2. Purge multiple URLs using wildcard:
   ```
   PURGE /cache/purge?url=/path/to/images/*.png
   ```

3. Purge all cache:
   ```
   PURGE /cache/purge?url=*&type=all
   ```

## Optional keyfinder helper setup

If your cache consists of a large number of files, scanning it with `grep` can become quite slow.
To gain better performance, you can use the included keyfinder helper. You'll have to build it yourself, however.

### Requirements
You will need golang. Tested with golang 1.23.

```bash
go build cache_keyfinder.go
```

### Configuration
Enable the keyfinder in your purge location config by setting the `cache_keyfinder` option in the init configuration:

```lua
local ok, err = cache_multipurge.init({
    cache_paths = {"/tmp/cache"},
    cache_keyfinder = "cache_keyfinder",
    cache_keyfinder_path = "/usr/local/bin/"  -- Optional: specify custom path
})
```
