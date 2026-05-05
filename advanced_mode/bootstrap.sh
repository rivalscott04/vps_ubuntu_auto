#!/bin/bash

# Loader modular untuk Advanced mode.
# Tetap source file legacy agar kompatibel penuh.

_root_dir="$(dirname "${BASH_SOURCE[0]}")/.."

source "${_root_dir}/utils.sh"
source "${_root_dir}/installers.sh"
source "${_root_dir}/configurators.sh"
source "${_root_dir}/advanced_mode/menu.sh"
