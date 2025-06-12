CC     = gcc
CFLAGS = -pedantic -Wall -Wextra -march=native -O3 -Wno-unused-parameter
TARGET = cache_keyfinder

all:
	$(CC) $(CFLAGS) -o $(TARGET) cache_keyfinder.c

install:
	install -D $(TARGET) $(PREFIX)/usr/local/openresty/bin/$(TARGET)
