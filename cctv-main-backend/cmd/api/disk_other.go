//go:build !linux

package main

// getDiskStats is not supported on non-Linux builds here.
func getDiskStats() (map[string]any, bool) {
    return nil, false
}

