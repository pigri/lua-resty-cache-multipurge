package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
)

const (
	bufSize = 1024
	keySize = 256
)

type cacheKeyFinder struct {
	keyPrefix string
	keySuffix string
	doDelete  bool
	hasError  bool
}

func (f *cacheKeyFinder) processFile(path string) error {
	fmt.Println("Processing file: ", path)
	file, err := os.Open(path)
	if err != nil {
		return nil // Skip files we can't open
	}
	defer file.Close()

	buf := make([]byte, bufSize)
	bytesRead, err := file.Read(buf)
	if err != nil && err != io.EOF {
		return nil
	}

	if bytesRead < 150 {
		fmt.Println("First file too small. Path incorrect?")
		os.Exit(1)
	}

	// Find KEY marker
	keyMarker := "\nKEY: "
	keyPos := strings.Index(string(buf), keyMarker)
	fmt.Println("Key marker position: ", keyPos)
	if keyPos == -1 {
		fmt.Println("Could not find key marker. Path incorrect?")
		os.Exit(1)
	}

	// Skip header and read again
	_, err = file.Seek(int64(keyPos), io.SeekStart)
	if err != nil {
		return nil
	}

	bytesRead, err = file.Read(buf)
	if err != nil && err != io.EOF {
		return nil
	}

	fmt.Printf("Debug - Content after key marker: %q\n", string(buf[:bytesRead]))
	fmt.Printf("Debug - Looking for prefix: %q\n", f.keyPrefix)

	// Check key prefix
	if bytesRead < len(f.keyPrefix) || !strings.HasPrefix(string(buf), f.keyPrefix) {
		fmt.Printf("Skipping file %s: prefix check failed (read %d bytes, prefix length %d)\n", path, bytesRead, len(f.keyPrefix))
		return nil
	}

	// Check key suffix if present
	if f.keySuffix != "" {
		end := strings.Index(string(buf), "\n")
		if end == -1 {
			fmt.Fprintf(os.Stderr, "Invalid cache file \"%s\" encountered and skipped.\n", path)
			f.hasError = true
			return nil
		}

		fmt.Printf("Debug - Checking suffix in: %q\n", string(buf[:end]))
		fmt.Printf("Debug - Looking for suffix: %q\n", f.keySuffix)

		ptr := end - len(f.keySuffix)
		if ptr < 0 || !strings.HasSuffix(string(buf[:end]), f.keySuffix) {
			fmt.Printf("Skipping file %s: suffix check failed\n", path)
			return nil
		}
	} else {
		fmt.Printf("Debug - No suffix provided, skipping suffix check\n")
	}

	if f.doDelete {
		fmt.Printf("Deleting file: %s\n", path)
		return os.Remove(path)
	} else {
		fmt.Println(path)
	}

	return nil
}

func main() {
	args := os.Args[1:]
	if len(args) < 2 || len(args) > 4 {
		fmt.Printf("Find/unlink nginx cache files fast\n\n"+
			"Usage: %s <path> <keyprefix> [keysuffix] [-d]\n\n"+
			"Optional parameter -d unlinks found cache files\n\n", os.Args[0])
		os.Exit(1)
	}

	// Check if -d flag is present
	doDelete := false
	path := args[0]
	keyPrefix := args[1]
	var keySuffix string

	// Handle optional arguments
	if len(args) == 3 {
		if args[2] == "-d" {
			doDelete = true
		} else {
			keySuffix = args[2]
		}
	} else if len(args) == 4 {
		if args[3] == "-d" {
			doDelete = true
			keySuffix = args[2]
		} else {
			fmt.Printf("Invalid flag: %s\n", args[3])
			os.Exit(1)
		}
	}

	finder := &cacheKeyFinder{
		keyPrefix: "\nKEY: " + keyPrefix,
		keySuffix: keySuffix,
		doDelete:  doDelete,
	}

	err := filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			return finder.processFile(path)
		}
		return nil
	})

	if err != nil {
		fmt.Fprintf(os.Stderr, "Error walking path: %v\n", err)
		os.Exit(1)
	}

	if finder.hasError {
		os.Exit(1)
	}
}
