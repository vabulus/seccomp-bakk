#!/usr/bin/env python3
import sys
import lief
import json
import struct
import os
import shutil
import subprocess


def filter_file(fname):
    f = fname.replace("/", "_") + ".json"
    if f[0] == ".":
        f = f[1:]
    return f


def main(fname):
    # load filter
    ffname = "policy_%s" % filter_file(fname)
    try:
        filters = json.loads(open(ffname).read())
    except:
        print("[-] Could not load filter file %s" % ffname)
        return 1
    print("[+] Allowed syscalls: %d" % len(filters["syscalls"]))

    # inject sandboxing library: copy original and use patchelf
    patched = "%s_patched" % fname
    shutil.copy2(fname, patched)
    for lib in ("libchestnut.so", "libseccomp.so.2"):
        subprocess.check_call(["patchelf", "--add-needed", lib, patched])

    # append filter blob
    with open(patched, "ab") as elf:
        filter_data = json.dumps(filters).encode()
        elf.write(filter_data)
        elf.write(struct.pack("I", len(filter_data)))
    os.chmod(patched, 0o755)
    print("[+] Saved patched binary as %s" % patched)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: %s <binary>" % sys.argv[0])
        sys.exit(1)
    sys.exit(main(sys.argv[1]))
