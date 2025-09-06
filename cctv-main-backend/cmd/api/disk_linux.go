//go:build linux

package main

import (
    "golang.org/x/sys/unix"
)

// getDiskStats returns basic disk stats for root filesystem on Linux.
func getDiskStats() (map[string]any, bool) {
    var sfs unix.Statfs_t
    if err := unix.Statfs("/", &sfs); err != nil {
        return nil, false
    }
    return map[string]any{
        "total": sfs.Blocks * uint64(sfs.Bsize),
        "free":  sfs.Bavail * uint64(sfs.Bsize),
    }, true
}

