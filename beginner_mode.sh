#!/bin/bash

# Loader modular untuk Simple/Beginner mode
_beginner_dir="$(dirname "${BASH_SOURCE[0]}")/beginner_mode"

source "${_beginner_dir}/common.sh"
source "${_beginner_dir}/detection.sh"
source "${_beginner_dir}/dependencies.sh"
source "${_beginner_dir}/provision.sh"
source "${_beginner_dir}/features.sh"
