#!/bin/sh
printf '\033c\033]0;%s\a' 'Squash the Creeps (3D)'
base_path="$(dirname "$(realpath "$0")")"
"$base_path/coop_game.x86_64" "$@"
