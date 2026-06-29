# shell_hooks.sh - Automatically sourced shell hooks for sentry/dotfiles package tracking.
# Drop this into your shell rc file (.bashrc or .zshrc) via the bootstrap script.

_dotfiles_log_pkg() {
    # Try calling dotfiles command
    if command -v dotfiles >/dev/null 2>&1; then
        dotfiles "$@"
    elif [ -f "/home/skc/dev/dotfiles/.venv/bin/dotfiles" ]; then
        "/home/skc/dev/dotfiles/.venv/bin/dotfiles" "$@"
    fi
}

_sentry_parse_and_log() {
    local manager="$1"
    local action="$2" # "install" or "uninstall"
    shift 2
    for arg in "$@"; do
        if [[ "$arg" == -* ]]; then
            continue
        fi
        # Skip package manager subcommands
        if [[ "$arg" == "install" || "$arg" == "uninstall" || "$arg" == "remove" || "$arg" == "erase" || "$arg" == "reinstall" || "$arg" == "autoremove" ]]; then
            continue
        fi
        if [[ -z "$arg" || "$arg" == "." ]]; then
            continue
        fi
        
        if [ "$action" = "install" ]; then
            _dotfiles_log_pkg log --pkg "${manager}:${arg}"
        else
            _dotfiles_log_pkg remove-pkg "$manager" "$arg"
        fi
    done
}

_sentry_parse_flatpak() {
    local action="$1"
    shift
    local args=()
    for arg in "$@"; do
        if [[ "$arg" == -* || "$arg" == "install" || "$arg" == "uninstall" ]]; then
            continue
        fi
        args+=("$arg")
    done
    
    # Filter flatpak remotes (e.g. flathub)
    for ref in "${args[@]}"; do
        if [[ "$ref" == *.* || ${#args[@]} -eq 1 ]]; then
            if [ "$action" = "install" ]; then
                _dotfiles_log_pkg log --pkg "flatpak:$ref"
            else
                _dotfiles_log_pkg remove-pkg "flatpak" "$ref"
            fi
        fi
    done
}

_sentry_parse_pip() {
    local action="$1"
    shift
    for arg in "$@"; do
        if [[ "$arg" == -* || "$arg" == "install" || "$arg" == "uninstall" || "$arg" == "pip" ]]; then
            continue
        fi
        if [[ -f "$arg" || -d "$arg" ]]; then
            continue
        fi
        if [ "$action" = "install" ]; then
            _dotfiles_log_pkg log --pkg "pip:$arg"
        else
            _dotfiles_log_pkg remove-pkg "pip" "$arg"
        fi
    done
}

_sentry_parse_pipx() {
    local action="$1"
    shift
    for arg in "$@"; do
        if [[ "$arg" == -* || "$arg" == "install" || "$arg" == "uninstall" || "$arg" == "pipx" ]]; then
            continue
        fi
        if [ "$action" = "install" ]; then
            _dotfiles_log_pkg log --pkg "pipx:$arg"
        else
            _dotfiles_log_pkg remove-pkg "pipx" "$arg"
        fi
    done
}

_sentry_parse_uv() {
    local is_pip=0
    local is_tool=0
    local is_inst=0
    local is_uninst=0
    for arg in "$@"; do
        if [[ "$arg" == "pip" ]]; then
            is_pip=1
        elif [[ "$arg" == "tool" ]]; then
            is_tool=1
        elif [[ "$arg" == "install" || "$arg" == "add" ]]; then
            is_inst=1
        elif [[ "$arg" == "uninstall" || "$arg" == "remove" ]]; then
            is_uninst=1
        fi
    done

    if [ $is_inst -eq 1 ] || [ $is_uninst -eq 1 ]; then
        local action="install"
        if [ $is_uninst -eq 1 ]; then
            action="uninstall"
        fi
        
        for arg in "$@"; do
            if [[ "$arg" == -* || "$arg" == "pip" || "$arg" == "tool" || "$arg" == "install" || "$arg" == "uninstall" || "$arg" == "add" || "$arg" == "remove" ]]; then
                continue
            fi
            if [[ -f "$arg" || -d "$arg" || "$arg" == "." ]]; then
                continue
            fi
            if [ "$action" = "install" ]; then
                _dotfiles_log_pkg log --pkg "uv:$arg"
            else
                _dotfiles_log_pkg remove-pkg "uv" "$arg"
            fi
        done
    fi
}

# Wrappers
dnf() {
    command dnf "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        for arg in "$@"; do
            if [[ "$arg" == "install" || "$arg" == "reinstall" ]]; then
                _sentry_parse_and_log "dnf" "install" "$@"
                break
            elif [[ "$arg" == "remove" || "$arg" == "erase" ]]; then
                _sentry_parse_and_log "dnf" "uninstall" "$@"
                break
            fi
        done
    fi
    return $exit_code
}

flatpak() {
    command flatpak "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        local is_inst=0
        local is_uninst=0
        for arg in "$@"; do
            if [[ "$arg" == "install" ]]; then
                is_inst=1
            elif [[ "$arg" == "uninstall" ]]; then
                is_uninst=1
            fi
        done
        if [ $is_inst -eq 1 ]; then
            _sentry_parse_flatpak "install" "$@"
        elif [ $is_uninst -eq 1 ]; then
            _sentry_parse_flatpak "uninstall" "$@"
        fi
    fi
    return $exit_code
}

pip() {
    command pip "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        local is_inst=0
        local is_uninst=0
        for arg in "$@"; do
            if [[ "$arg" == "install" ]]; then
                is_inst=1
            elif [[ "$arg" == "uninstall" ]]; then
                is_uninst=1
            fi
        done
        if [ $is_inst -eq 1 ]; then
            _sentry_parse_pip "install" "$@"
        elif [ $is_uninst -eq 1 ]; then
            _sentry_parse_pip "uninstall" "$@"
        fi
    fi
    return $exit_code
}

pipx() {
    command pipx "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        local is_inst=0
        local is_uninst=0
        for arg in "$@"; do
            if [[ "$arg" == "install" ]]; then
                is_inst=1
            elif [[ "$arg" == "uninstall" ]]; then
                is_uninst=1
            fi
        done
        if [ $is_inst -eq 1 ]; then
            _sentry_parse_pipx "install" "$@"
        elif [ $is_uninst -eq 1 ]; then
            _sentry_parse_pipx "uninstall" "$@"
        fi
    fi
    return $exit_code
}

uv() {
    command uv "$@"
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        _sentry_parse_uv "$@"
    fi
    return $exit_code
}

sudo() {
    if [[ "$1" == "dnf" ]]; then
        command sudo "$@"
        local exit_code=$?
        if [ $exit_code -eq 0 ]; then
            # Parse starting from the next argument
            shift
            for arg in "$@"; do
                if [[ "$arg" == "install" || "$arg" == "reinstall" ]]; then
                    _sentry_parse_and_log "dnf" "install" "$@"
                    break
                elif [[ "$arg" == "remove" || "$arg" == "erase" ]]; then
                    _sentry_parse_and_log "dnf" "uninstall" "$@"
                    break
                fi
            done
        fi
        return $exit_code
    else
        command sudo "$@"
    fi
}
