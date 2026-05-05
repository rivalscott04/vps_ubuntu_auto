#!/bin/bash

detect_app_type() {
    local app_path="$1"
    DETECTED_TYPE="unknown"
    DETECT_CONFIDENCE="low"
    DETECT_REASONS=()

    if [ ! -d "$app_path" ]; then
        DETECT_REASONS+=("Path aplikasi tidak ditemukan")
        return 1
    fi

    if [ -f "$app_path/artisan" ] && [ -f "$app_path/composer.json" ] && [ -f "$app_path/public/index.php" ]; then
        DETECTED_TYPE="laravel"
        DETECT_CONFIDENCE="high"
        DETECT_REASONS+=("Ditemukan artisan, composer.json, public/index.php")
        return 0
    fi

    if [ -f "$app_path/wp-config.php" ] || [ -f "$app_path/wp-settings.php" ]; then
        DETECTED_TYPE="wordpress"
        DETECT_CONFIDENCE="high"
        DETECT_REASONS+=("Ditemukan file inti WordPress")
        return 0
    fi

    if [ -f "$app_path/package.json" ]; then
        if rg -n "\"next\"" "$app_path/package.json" >/dev/null 2>&1; then
            DETECTED_TYPE="nextjs"
            DETECT_CONFIDENCE="medium"
            DETECT_REASONS+=("package.json mengandung dependency/script next")
            return 0
        fi
        if [ -d "$app_path/dist" ]; then
            DETECTED_TYPE="react-static"
            DETECT_CONFIDENCE="medium"
            DETECT_REASONS+=("package.json ada dan folder dist ditemukan")
            return 0
        fi
        DETECTED_TYPE="nodejs"
        DETECT_CONFIDENCE="medium"
        DETECT_REASONS+=("package.json ditemukan")
        return 0
    fi

    if [ -f "$app_path/manage.py" ]; then
        DETECTED_TYPE="django"
        DETECT_CONFIDENCE="medium"
        DETECT_REASONS+=("manage.py ditemukan")
        return 0
    fi

    if [ -f "$app_path/index.php" ]; then
        DETECTED_TYPE="php"
        DETECT_CONFIDENCE="low"
        DETECT_REASONS+=("index.php ditemukan")
        return 0
    fi

    DETECT_REASONS+=("Tidak ada signature framework yang kuat")
    return 0
}

show_detection_result() {
    echo "Deteksi stack: $DETECTED_TYPE (confidence: $DETECT_CONFIDENCE)"
    for reason in "${DETECT_REASONS[@]}"; do
        echo "- $reason"
    done
}

find_project_candidates() {
    local root_path="$1"
    CANDIDATE_PATHS=()
    CANDIDATE_TYPES=()

    detect_app_type "$root_path"
    if [ "$DETECTED_TYPE" != "unknown" ]; then
        CANDIDATE_PATHS+=("$root_path")
        CANDIDATE_TYPES+=("$DETECTED_TYPE")
    fi

    while IFS= read -r subdir; do
        detect_app_type "$subdir"
        if [ "$DETECTED_TYPE" != "unknown" ]; then
            CANDIDATE_PATHS+=("$subdir")
            CANDIDATE_TYPES+=("$DETECTED_TYPE")
        fi
    done < <(find "$root_path" -mindepth 1 -maxdepth 3 -type d \
        ! -path "*/.git/*" \
        ! -path "*/node_modules/*" \
        ! -path "*/vendor/*" 2>/dev/null)
}

select_project_from_candidates() {
    local root_path="$1"
    local i
    find_project_candidates "$root_path"

    if [ "${#CANDIDATE_PATHS[@]}" -eq 0 ]; then
        log_warning "Belum ditemukan project terdeteksi di path ini."
        SELECTED_PROJECT_PATH="$root_path"
        SELECTED_PROJECT_TYPE="unknown"
        return 0
    fi

    if [ "${#CANDIDATE_PATHS[@]}" -eq 1 ]; then
        SELECTED_PROJECT_PATH="${CANDIDATE_PATHS[0]}"
        SELECTED_PROJECT_TYPE="${CANDIDATE_TYPES[0]}"
        log_info "Project terdeteksi: ${SELECTED_PROJECT_TYPE} di ${SELECTED_PROJECT_PATH}"
        return 0
    fi

    echo "Terdeteksi beberapa project (monorepo/multi-project):"
    for i in "${!CANDIDATE_PATHS[@]}"; do
        printf "%s) [%s] %s\n" "$((i+1))" "${CANDIDATE_TYPES[$i]}" "${CANDIDATE_PATHS[$i]}"
    done

    while true; do
        read -r -p "Pilih nomor project target [1-${#CANDIDATE_PATHS[@]}]: " pick
        if [[ "$pick" =~ ^[0-9]+$ ]] && [ "$pick" -ge 1 ] && [ "$pick" -le "${#CANDIDATE_PATHS[@]}" ]; then
            local idx=$((pick-1))
            SELECTED_PROJECT_PATH="${CANDIDATE_PATHS[$idx]}"
            SELECTED_PROJECT_TYPE="${CANDIDATE_TYPES[$idx]}"
            break
        fi
        log_error "Pilihan tidak valid."
    done
    log_info "Target dipilih: ${SELECTED_PROJECT_TYPE} di ${SELECTED_PROJECT_PATH}"
}
