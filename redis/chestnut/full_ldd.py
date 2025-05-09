#!/usr/bin/env python

# adapted from https://gitweb.gentoo.org/proj/elfix.git/tree/pocs/ldd/ldd.py

import os, sys
import re, glob

from elftools import __version__
from elftools.common.exceptions import ELFError
from elftools.elf.elffile import ELFFile
from elftools.elf.dynamic import DynamicSection
from elftools.elf.descriptions import describe_ei_class


class ReadElf(object):
    def __init__(self, file):
        """file: stream object with the ELF file to read"""
        self.elffile = ELFFile(file)

    def elf_class(self):
        """Return the ELF Class"""
        header = self.elffile.header
        e_ident = header["e_ident"]
        return describe_ei_class(e_ident["EI_CLASS"])

    def dynamic_dt_needed(self):
        """Return a list of the DT_NEEDED"""
        dt_needed = []
        for section in self.elffile.iter_sections():
            if not isinstance(section, DynamicSection):
                continue

            for tag in section.iter_tags():
                if tag.entry.d_tag == "DT_NEEDED":
                    dt_needed.append(str(tag.needed))
                    # sys.stdout.write('\t%s\n' % str(tag.needed) )

        return dt_needed


def ldpaths(ld_so_conf="/etc/ld.so.conf"):
    """Generate paths to search for libraries from ld.so.conf.  Recursively
    parse included files.  We assume correct syntax and the ld.so.cache
    is in sync with ld.so.conf.
    """
    with open(ld_so_conf, "r") as path_file:
        lines = path_file.read()
    lines = re.sub("#.*", "", lines)  # kill comments
    lines = list(re.split(":+|\s+|\t+|\n+|,+", lines))  # man 8 ldconfig

    paths = []
    include_globs = []
    for i in range(0, len(lines)):
        if lines[i] == "":
            continue
        if lines[i] == "include":
            f = lines[i + 1]
            include_globs.append(f)
            continue
        if lines[i] not in include_globs:
            real_path = os.path.realpath(lines[i])
            if os.path.exists(real_path):
                paths.append(real_path)

    include_files = []
    for g in include_globs:
        include_files = include_files + glob.glob(g)
    for c in include_files:
        paths = paths + ldpaths(os.path.realpath(c))

    # add the default lib directory as the previous code does not seem to include it
    paths.append("/lib")
    paths = list(set(paths))
    paths.sort()
    return paths


# We cache the dependencies for speed.  The structure is
# { ELFClass : { SONAME : library, ... }, ELFClass : ... }
cache = {}


def dynamic_dt_needed_paths(dt_needed, eclass, paths):
    """Search library paths for the library file corresponding
    to the given DT_NEEDED and ELF Class.
    """
    global cache
    if not eclass in cache:
        cache[eclass] = {}

    dt_needed_paths = {}
    for n in dt_needed:
        if n in cache[eclass].keys():
            dt_needed_paths[n] = cache[eclass][n]
        else:
            for p in paths:
                lib = p + os.sep + n
                if os.path.exists(lib):
                    with open(lib, "rb") as file:
                        try:
                            readlib = ReadElf(file)
                            if eclass == readlib.elf_class():
                                dt_needed_paths[n] = lib
                                cache[eclass][n] = lib
                        except ELFError as ex:
                            sys.stderr.write("ELF error: %s\n" % ex)
                            sys.exit(1)

    return dt_needed_paths


def all_dynamic_dt_needed_paths(f, paths, depth=0):
    """Return a dictionary of all the DT_NEEDED => Library Paths for
    a given ELF file obtained by recursively following linkage.
    """
    with open(f, "rb") as file:
        try:
            readelf = ReadElf(file)
            eclass = readelf.elf_class()
            # This needs to be iterated until we traverse the entire linkage tree
            dt_needed = readelf.dynamic_dt_needed()
            dt_needed_paths = dynamic_dt_needed_paths(dt_needed, eclass, paths)
            # max depth to prevent infinite loops
            if (
                depth > 10
            ):  # random max number, increasing to 30 does not seem to make a difference...
                return dt_needed_paths
            for n, lib in dt_needed_paths.items():
                dt_needed_paths = dict(
                    all_dynamic_dt_needed_paths(lib, paths, depth + 1),
                    **dt_needed_paths,
                )
        except ELFError as ex:
            sys.stderr.write("ELF error: %s\n" % ex)
            sys.exit(1)

    return dt_needed_paths


def get_dependencies(fname):
    paths = ldpaths()

    all_dt_needed_paths = all_dynamic_dt_needed_paths(fname, paths)
    dep = []
    for n, lib in all_dt_needed_paths.items():
        dep.append(lib)
    return dep


def is_static(fname):
    with open(fname, "rb") as f:
        try:
            elf = ELFFile(f)
            for segment in elf.iter_segments():
                if segment.header.p_type == "PT_DYNAMIC":
                    return False
        except ELFError as ex:
            sys.stderr.write("Elf error: %s\n" % ex)
            sys.exit(1)
    return True


def main():
    dep = get_dependencies(sys.argv[1])
    for d in dep:
        print(d)


if __name__ == "__main__":
    main()
