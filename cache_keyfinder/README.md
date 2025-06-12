# Cache Key Finder

A fast and efficient tool for finding and optionally deleting nginx cache files based on key prefixes and suffixes.

## Description

Cache Key Finder is a command-line utility designed to quickly locate and optionally remove nginx cache files. It's particularly useful for managing large cache directories where you need to find or purge specific cached items based on their key patterns.

## Features

- Fast file scanning with minimal memory usage
- Support for key prefix matching
- Optional key suffix matching
- Ability to delete matching cache files
- Efficient file handling with buffered reads
- Detailed debug output for troubleshooting

## Usage

```bash
./cache_keyfinder <path> <keyprefix> [keysuffix] [-d]
```

### Parameters

- `path`: The directory path to search for cache files
- `keyprefix`: The prefix of the cache key to match
- `keysuffix`: (Optional) The suffix of the cache key to match
- `-d`: (Optional) Delete matching cache files instead of just listing them

### Examples

1. List all cache files with a specific prefix:
```bash
./cache_keyfinder /var/cache/nginx "example.com"
```

2. List cache files matching both prefix and suffix:
```bash
./cache_keyfinder /var/cache/nginx "example.com" ".html"
```

3. Delete all cache files matching a prefix:
```bash
./cache_keyfinder /var/cache/nginx "example.com" -d
```

4. Delete cache files matching both prefix and suffix:
```bash
./cache_keyfinder /var/cache/nginx "example.com" ".html" -d
```

## How It Works

The tool scans through the specified directory and its subdirectories, examining each file for cache key patterns. It uses a buffered reading approach to efficiently process files without loading them entirely into memory.

For each file, it:
1. Checks for the presence of a "KEY:" marker
2. Validates the key prefix
3. Optionally validates the key suffix
4. Either lists the matching files or deletes them if the `-d` flag is specified

## Error Handling

- The tool will skip files it cannot open
- Invalid cache files are reported but skipped
- The tool exits with status code 1 if any errors occur during processing
- Detailed error messages are provided for troubleshooting

## Requirements

- Go 1.x or later
- Access to the nginx cache directory
- Appropriate permissions to read/delete cache files

## Building

To build the tool from source:

```bash
go build -o cache_keyfinder cache_keyfinder.go
```
