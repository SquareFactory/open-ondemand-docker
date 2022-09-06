#!/bin/sh
# $0: pun_pre_hook_root_cmd.sh
# $1: --name
# $2: <name>

HOME_DIR="$(getent passwd "$2" | cut -d : -f 6)"

if [ ! -d "${HOME_DIR}" ]; then
  mkhomedir_helper "$2" 0077
fi
