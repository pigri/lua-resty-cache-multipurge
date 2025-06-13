OPENRESTY_PREFIX=/usr/local/openresty

LUA_LIB_DIR ?=     $(OPENRESTY_PREFIX)/lualib
INSTALL ?= install

.PHONY: all build install

all: build install;

install: all
	$(INSTALL) lib/resty/cache_multipurge.lua $(LUA_LIB_DIR)/resty/cache_multipurge.lua
	$(INSTALL) cache_keyfinder/cache_keyfinder $(OPENRESTY_PREFIX)/bin/cache_keyfinder

build:
	go build -o cache_keyfinder/cache_keyfinder cache_keyfinder/cache_keyfinder.go
