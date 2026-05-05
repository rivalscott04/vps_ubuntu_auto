#!/bin/bash

LEARNING_MODE=${LEARNING_MODE:-0}

beginner_note() {
    local msg="$1"
    if [ "$LEARNING_MODE" = "1" ]; then
        echo "[Belajar] $msg"
    fi
}

prompt_with_default() {
    local label="$1"
    local default_value="$2"
    local result=""
    read -r -p "$label [$default_value]: " result
    if [ -z "$result" ]; then
        result="$default_value"
    fi
    echo "$result"
}

is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[A-Za-z0-9][A-Za-z0-9.-]*[A-Za-z0-9]$ ]] && [[ "$domain" == *.* ]]
}

is_valid_port() {
    local port="$1"
    [[ "$port" =~ ^[0-9]+$ ]] && [ "$port" -ge 1 ] && [ "$port" -le 65535 ]
}

detect_installed_php_version() {
    local detected
    detected=$(ls /etc/php 2>/dev/null | sort -Vr | head -n1)
    echo "$detected"
}

toggle_learning_mode() {
    if [ "$LEARNING_MODE" = "1" ]; then
        LEARNING_MODE=0
        log_info "Mode belajar: OFF"
    else
        LEARNING_MODE=1
        log_info "Mode belajar: ON"
    fi
}
