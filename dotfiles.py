import os
import sys
import json
import subprocess
from datetime import datetime
import httpx
import typer
import toml
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich.prompt import Prompt

app = typer.Typer(help="Sentry / Dotfiles Backup and Restore Tool")
console = Console()

# Resolve paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

def load_config():
    paths_to_try = [
        os.path.join(SCRIPT_DIR, "config.toml"),
        os.path.expanduser("~/dotfiles/config.toml"),
        os.path.expanduser("~/.config/dotfiles/config.toml"),
        "/home/skc/dev/dotfiles/config.toml"
    ]
    for p in paths_to_try:
        if os.path.exists(p):
            try:
                return toml.load(p)
            except Exception as e:
                console.print(f"[yellow]Warning: failed to parse config at {p}: {e}[/yellow]")
    
    # Return basic defaults if no config found
    return {
        "gemini": {"enabled": False, "api_key": ""},
        "github": {"username": "skc", "token": ""},
        "paths": {
            "dev_dir": "~/dev",
            "applications_dir": "~/Applications",
            "dotfiles_dir": "/home/skc/dev/dotfiles"
        },
        "backup": {
            "schedule": "daily",
            "time": "03:00",
            "heavy_dest": "/tmp/heavy_backup",
            "heavy_folders": [],
            "rsync_exclude": []
        },
        "appimage": {"mode": "log_only"},
        "watch": {"paths": []},
        "stow": {"package_map": {}}
    }

CONFIG = load_config()

# Resolve dotfiles paths from config
configured_dotfiles_dir = os.path.abspath(os.path.expanduser(CONFIG["paths"].get("dotfiles_dir", "~/dotfiles")))
DOTFILES_DIR = configured_dotfiles_dir

# Self-healing fallback if configured path is not a git repository
if not os.path.exists(os.path.join(DOTFILES_DIR, ".git")):
    if os.path.exists(os.path.join(SCRIPT_DIR, ".git")):
        DOTFILES_DIR = SCRIPT_DIR
        console.print(f"[yellow]Warning: Configured dotfiles_dir '{configured_dotfiles_dir}' is not a git repository. "
                      f"Falling back to script repository at '{DOTFILES_DIR}'.[/yellow]")

LOGS_DIR = os.path.join(DOTFILES_DIR, "logs")
PENDING_FILE = os.path.join(LOGS_DIR, "pending.json")
CHANGELOG_FILE = os.path.join(LOGS_DIR, "changelog.log")
STOW_DIR = os.path.join(DOTFILES_DIR, "stow")
PACKAGES_DIR = os.path.join(DOTFILES_DIR, "packages")
SYSTEM_DIR = os.path.join(DOTFILES_DIR, "system")

# Ensure necessary directories exist
for d in [LOGS_DIR, STOW_DIR, PACKAGES_DIR, SYSTEM_DIR]:
    os.makedirs(d, exist_ok=True)

# Helper to read/write pending
def load_pending():
    if os.path.exists(PENDING_FILE):
        try:
            with open(PENDING_FILE, "r") as f:
                data = json.load(f)
                # Ensure structure
                if "packages" not in data:
                    data["packages"] = {}
                if "files" not in data:
                    data["files"] = []
                return data
        except Exception:
            pass
    return {"packages": {"dnf": [], "flatpak": [], "pip": [], "pipx": [], "uv": []}, "files": []}

def save_pending(data):
    with open(PENDING_FILE, "w") as f:
        json.dump(data, f, indent=2)

def log_changelog(entry_type, details):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    line = f"[{timestamp}] {entry_type}: {details}\n"
    with open(CHANGELOG_FILE, "a") as f:
        f.write(line)

# Ignore patterns checks
def is_ignored(path_str):
    filename = os.path.basename(path_str)
    # Check basic ignore list (excluding sensitive credential files)
    ignore_substrings = [
        ".git", "__pycache__", ".pyc", "pending.json", "changelog.log",
        ".swp", ".tmp", ".obsidian", ".trash", "hosts.yml", "api_keys.toml",
        "id_rsa", "id_ed25519", "credentials", ".env"
    ]
    if any(sub in path_str for sub in ignore_substrings):
        return True
    if filename.endswith("~"):
        return True
    # Ignore the binary itself
    if filename == "dotfiles" and (".local/bin" in path_str or "dev/dotfiles" in path_str):
        return True
    # Ignore any path inside the dotfiles stow directory itself
    if path_str.startswith(STOW_DIR):
        return True
    
    # Check if symlink pointing to stow
    if os.path.islink(path_str):
        target = os.readlink(path_str)
        if STOW_DIR in os.path.abspath(target):
            return True
            
    return False

# Package mapping and stow helper
def find_stow_package(file_path):
    # Try mapping using config
    rel_to_home = file_path
    home = os.path.expanduser("~")
    if file_path.startswith(home):
        rel_to_home = os.path.relpath(file_path, home)
    
    package_map = CONFIG.get("stow", {}).get("package_map", {})
    
    # Find exact or prefix matches
    for prefix, pkg in package_map.items():
        if rel_to_home.startswith(prefix):
            return pkg
    return None

def robust_move(src, dst):
    import shutil
    # If destination exists and both are directories, merge recursively
    if os.path.exists(dst) and os.path.isdir(dst) and os.path.isdir(src):
        requires_sudo = False
        for entry in os.scandir(src):
            sub_src = entry.path
            sub_dst = os.path.join(dst, entry.name)
            if robust_move(sub_src, sub_dst):
                requires_sudo = True
        # remove original empty directory
        try:
            os.rmdir(src)
        except Exception:
            subprocess.run(["sudo", "rm", "-rf", src], check=True)
            requires_sudo = True
        return requires_sudo

    # Otherwise, move/replace file or directory
    if os.path.exists(dst):
        try:
            if os.path.isdir(dst):
                shutil.rmtree(dst)
            else:
                os.remove(dst)
        except Exception:
            subprocess.run(["sudo", "rm", "-rf", dst], check=True)
            
    try:
        shutil.move(src, dst)
        return False
    except Exception:
        subprocess.run(["sudo", "mv", src, dst], check=True)
        return True

def stow_file(file_path, pkg_name):
    home = os.path.expanduser("~")
    if not file_path.startswith(home):
        console.print(f"[red]Error: Stow only supports home directory configurations. Cannot stow {file_path}[/red]")
        return False
        
    rel_path = os.path.relpath(file_path, home)
    dest_path = os.path.join(STOW_DIR, pkg_name, rel_path)
    
    # Create destination directories
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    
    # Move the file/folder to stow directory
    try:
        requires_sudo = robust_move(file_path, dest_path)
        
        # Fix ownership inside stow folder if it was moved with sudo (owned by root)
        if requires_sudo:
            try:
                import pwd, grp
                user = pwd.getpwuid(os.getuid()).pw_name
                group = grp.getgrgid(os.getgid()).gr_name
                subprocess.run(["sudo", "chown", "-R", f"{user}:{group}", os.path.join(STOW_DIR, pkg_name)], check=True)
            except Exception:
                pass
            
        # Run stow
        cmd = ["stow", "-d", STOW_DIR, "-t", home, pkg_name]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            console.print(f"[green]Stowed {file_path} -> package '{pkg_name}'[/green]")
            return True
        else:
            console.print(f"[red]Stow failed: {res.stderr}[/red]")
            # Attempt to restore
            robust_move(dest_path, file_path)
            return False
    except Exception as e:
        console.print(f"[red]Failed to move and stow file: {e}[/red]")
        return False

def log_manual_installation(type_prefix, name):
    manual_file = os.path.join(PACKAGES_DIR, "manual_install.txt")
    existing = []
    if os.path.exists(manual_file):
        with open(manual_file, "r") as f:
            existing = [line.strip() for line in f if line.strip()]
    
    entry = f"{type_prefix}: {name}"
    if entry not in existing:
        existing.append(entry)
        header = [
            "# manual_install.txt - List of applications to install manually during restoration.",
            "# Add AppImage or manual RPM filenames here."
        ]
        non_comments = sorted([line for line in existing if not line.startswith("#")])
        with open(manual_file, "w") as f:
            for h in header:
                f.write(f"{h}\n")
            for item in non_comments:
                f.write(f"{item}\n")

# Git backup helper
def generate_commit_message(diff_summary):
    enabled = CONFIG.get("gemini", {}).get("enabled", True)
    if not enabled:
        return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"

    # Try to load API keys and custom models from ~/Documents/api_keys.toml
    keys_path = os.path.expanduser("~/Documents/api_keys.toml")
    api_keys = []
    model_list = [
        "gemini-2.5-flash-lite",
        "gemini-3.1-flash-lite",
        "gemini-2.5-flash",
        "gemini-3-flash",
        "gemini-3.5-flash",
        "gemini-2.0-flash",
    ]

    if os.path.exists(keys_path):
        try:
            import tomllib
            with open(keys_path, "rb") as f:
                keys_data = tomllib.load(f)
                api_keys = keys_data.get("gemini_api_keys", [])
                if not api_keys and "api_key" in keys_data:
                    api_keys = [keys_data["api_key"]]
                if "models" in keys_data:
                    model_list = keys_data["models"]
        except Exception:
            pass

    # Fallback to config.toml if no keys found in Documents
    if not api_keys:
        config_key = CONFIG.get("gemini", {}).get("api_key", "")
        if config_key:
            api_keys = [config_key]

    if not api_keys:
        return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"

    import time
    start_time = time.time()
    total_timeout = 10.0

    # Roll over models (lightest first) and multiple keys
    for model in model_list:
        for api_key in api_keys:
            if not api_key:
                continue
            
            elapsed = time.time() - start_time
            if elapsed >= total_timeout - 1.0:
                console.print("[yellow]Gemini generation timed out. Using default commit message.[/yellow]")
                return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"
                
            try:
                url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
                prompt = (
                    "Generate a clean conventional commit message (e.g., 'feat: add mako config', 'fix: correct hosts file') "
                    "for the following git changes summary. Return ONLY the commit message text, with no markdown formatting or extra text:\n\n"
                    f"{diff_summary}"
                )
                payload = {
                    "contents": [{
                        "parts": [{
                            "text": prompt
                        }]
                    }]
                }
                
                req_timeout = max(1.0, total_timeout - elapsed)
                res = httpx.post(url, json=payload, timeout=req_timeout)
                if res.status_code == 200:
                    content = res.json()
                    message = content["contents"][0]["parts"][0]["text"].strip()
                    if message.startswith("`") and message.endswith("`"):
                        message = message.strip("`")
                    if "\n" in message:
                        message = message.split("\n")[0]
                    return message
                else:
                    console.print(f"[yellow]Warning: Model {model} failed (HTTP {res.status_code}). Trying next combination...[/yellow]")
            except Exception as e:
                console.print(f"[yellow]Warning: Model {model} request failed ({e}). Trying next combination...[/yellow]")

    return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"

@app.command(rich_help_panel="Backup & Review")
def review():
    """Open TUI reviewer to review pending changes."""
    console.print(Panel("[bold green]Dotfiles / Sentry TUI Reviewer[/bold green]\nStarting review session...", expand=False))
    
    # 1. Before reviewing: automatically commits and pushes current state as a backup
    console.print("[cyan]Running pre-review backup...[/cyan]")
    run_git_backup(dry_run=False, message="pre-review auto backup")
    
    pending = load_pending()
    
    # Flatten packages to list of (manager, package_name)
    pending_packages = []
    for manager, pkgs in pending.get("packages", {}).items():
        for p in pkgs:
            pending_packages.append((manager, p))
            
    pending_files = pending.get("files", [])
    
    total_changes = len(pending_packages) + len(pending_files)
    if total_changes == 0:
        console.print("[green]No pending changes to review![/green]")
        return
        
    console.print(f"[bold]Found {total_changes} pending changes to review.[/bold]\n")
    
    accepted_packages = {}
    rejected_packages = {}
    
    accepted_files = []
    rejected_files = []
    
    yes_to_all = False
    skip_all = False
    
    # Review Packages
    for idx, (mgr, pkg) in enumerate(pending_packages):
        if skip_all:
            break
        if yes_to_all:
            accepted_packages.setdefault(mgr, []).append(pkg)
            continue
            
        console.print(Panel(f"[yellow]Package Change ({idx+1}/{total_changes})[/yellow]\nManager: [cyan]{mgr}[/cyan]\nPackage: [bold]{pkg}[/bold]"))
        ans = Prompt.ask(
            "Apply backup?",
            choices=["y", "n", "a", "s", "q"],
            default="y"
        ).lower()
        
        if ans == "q":
            console.print("[yellow]Quitting review session. Saving progress.[/yellow]")
            break
        elif ans == "a":
            yes_to_all = True
            accepted_packages.setdefault(mgr, []).append(pkg)
        elif ans == "s":
            skip_all = True
        elif ans == "y":
            accepted_packages.setdefault(mgr, []).append(pkg)
        elif ans == "n":
            rejected_packages.setdefault(mgr, []).append(pkg)

    # Review Files
    file_idx_start = len(pending_packages)
    for idx, f_entry in enumerate(pending_files):
        if skip_all:
            break
        f_path = f_entry["path"]
        f_type = f_entry["type"]
        f_time = f_entry["timestamp"]
        
        if yes_to_all:
            accepted_files.append(f_entry)
            continue
            
        console.print(Panel(f"[yellow]File Change ({file_idx_start+idx+1}/{total_changes})[/yellow]\nPath: [cyan]{f_path}[/cyan]\nType: {f_type}\nDetected: {f_time}"))
        ans = Prompt.ask(
            "Apply backup?",
            choices=["y", "n", "a", "s", "q"],
            default="y"
        ).lower()
        
        if ans == "q":
            console.print("[yellow]Quitting review session. Saving progress.[/yellow]")
            break
        elif ans == "a":
            yes_to_all = True
            accepted_files.append(f_entry)
        elif ans == "s":
            skip_all = True
        elif ans == "y":
            accepted_files.append(f_entry)
        elif ans == "n":
            rejected_files.append(f_entry)

    # Process Accepted Packages
    for mgr, pkgs in accepted_packages.items():
        list_file = os.path.join(PACKAGES_DIR, f"{mgr}.txt")
        existing = []
        if os.path.exists(list_file):
            with open(list_file, "r") as f:
                existing = [line.strip() for line in f if line.strip()]
        
        # Merge, remove duplicates, sort
        updated = sorted(list(set(existing + pkgs)))
        with open(list_file, "w") as f:
            for p in updated:
                f.write(f"{p}\n")
        
        for p in pkgs:
            log_changelog("INSTALLED", f"{p} ({mgr})")
            
    # Process Rejected Packages (just logs or ignores)
    for mgr, pkgs in rejected_packages.items():
        for p in pkgs:
            log_changelog("REJECTED_PACKAGE", f"{p} ({mgr})")
            
    # Process Accepted Files
    for f_entry in accepted_files:
        path = f_entry["path"]
        ftype = f_entry["type"]
        
        if ftype == "config" or ftype == "font" or ftype == "script":
            # Stow the file
            pkg = find_stow_package(path)
            if not pkg:
                console.print(f"[yellow]No Stow package mapped for: {path}[/yellow]")
                pkg = Prompt.ask("Enter stow package name to use (e.g. sway, scripts, fonts)")
                if pkg:
                    # Update config locally
                    # For simplicity, we just use it for this session
                    pass
            if pkg:
                if stow_file(path, pkg):
                    log_changelog("CONFIG", f"{os.path.basename(path)} stowed into package {pkg}")
            else:
                console.print(f"[red]Skipped stowing {path} (no package name provided).[/red]")
                
        elif ftype == "appimage":
            basename = os.path.basename(path)
            log_manual_installation("AppImage", basename)
            log_changelog("APPIMAGE", f"Logged AppImage path: {path}")
            console.print(f"[green]Logged AppImage name '{basename}' to packages/manual_install.txt[/green]")
            
        elif ftype == "rpm":
            basename = os.path.basename(path)
            log_manual_installation("RPM", basename)
            log_changelog("RPM", f"Logged RPM path: {path}")
            console.print(f"[green]Logged RPM name '{basename}' to packages/manual_install.txt[/green]")
                
        elif ftype == "system":
            # Copy file to system folder in dotfiles
            basename = os.path.basename(path)
            # handle special names
            if path == "/etc/hosts":
                basename = "hosts"
            elif path.endswith("mimeapps.list"):
                basename = "mimeapps.list"
                
            dest = os.path.join(SYSTEM_DIR, basename)
            try:
                import shutil
                shutil.copy2(path, dest)
                log_changelog("SYSTEM", f"Updated system backup file {basename}")
                console.print(f"[green]Copied system file to {dest}[/green]")
            except Exception as e:
                console.print(f"[red]Failed to backup system file {path}: {e}[/red]")

    # Update pending.json: remove reviewed items
    # Reviewed packages
    for mgr, pkgs in accepted_packages.items():
        for p in pkgs:
            if p in pending["packages"].get(mgr, []):
                pending["packages"][mgr].remove(p)
    for mgr, pkgs in rejected_packages.items():
        for p in pkgs:
            if p in pending["packages"].get(mgr, []):
                pending["packages"][mgr].remove(p)
                
    # Reviewed files
    reviewed_paths = {f["path"] for f in accepted_files + rejected_files}
    pending["files"] = [f for f in pending["files"] if f["path"] not in reviewed_paths]
    
    save_pending(pending)
    
    # 2. After reviewing: commits accepted changes locally with a Gemini-generated commit message
    console.print("[cyan]Generating commit message and committing accepted changes locally...[/cyan]")
    # Run git add and generate a commit message based on diff
    subprocess.run(["git", "add", "."], cwd=DOTFILES_DIR)
    
    diff_proc = subprocess.run(["git", "diff", "--cached", "--stat"], cwd=DOTFILES_DIR, capture_output=True, text=True)
    diff_summary = diff_proc.stdout.strip()
    
    if diff_summary:
        commit_msg = generate_commit_message(diff_summary)
        console.print(f"[green]Commit message: {commit_msg}[/green]")
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=DOTFILES_DIR)
    else:
        console.print("[yellow]No actual changes to commit after review.[/yellow]")

@app.command(rich_help_panel="Backup & Review")
def status():
    """Show pending changes without acting."""
    pending = load_pending()
    
    table = Table(title="Pending System Changes (Unreviewed)")
    table.add_column("Type", style="cyan")
    table.add_column("Item / Details", style="magenta")
    table.add_column("Timestamp / Status", style="green")
    
    # Packages
    pkg_count = 0
    for mgr, pkgs in pending.get("packages", {}).items():
        for p in pkgs:
            table.add_row(f"Package ({mgr})", p, "Pending")
            pkg_count += 1
            
    # Files
    file_count = len(pending.get("files", []))
    for f in pending.get("files", []):
        table.add_row(f"File ({f['type']})", f["path"], f["timestamp"])
        
    if pkg_count == 0 and file_count == 0:
        console.print("[green]System is completely in sync. No pending changes![/green]")
    else:
        console.print(table)
        console.print(f"\n[bold]Total pending changes: {pkg_count + file_count}[/bold]")
        console.print("Run [cyan]dotfiles review[/cyan] to process them.")

@app.command(rich_help_panel="Backup & Review")
def backup():
    """Run full backup now (Git repositories and heavy folders)."""
    console.print("[cyan]Running full backup...[/cyan]")
    # Backup Tier 1 (Git)
    console.print("[cyan]Starting Git backups...[/cyan]")
    run_git_backup()
    # Backup Tier 2 (Heavy folders)
    console.print("[cyan]Starting Heavy folders backup...[/cyan]")
    run_heavy_backup()
    console.print("[bold green]Backup complete![/bold green]")

@app.command(rich_help_panel="Imports & Migration")
def add(path: str):
    """Manually flag a file/directory to add to backup review."""
    abs_path = os.path.abspath(os.path.expanduser(path))
    if not os.path.exists(abs_path):
        console.print(f"[red]Error: Path {abs_path} does not exist[/red]")
        sys.exit(1)
        
    pending = load_pending()
    
    # Avoid duplicates
    for f in pending["files"]:
        if f["path"] == abs_path:
            console.print(f"[yellow]Path {abs_path} is already pending review.[/yellow]")
            return
            
    # Determine type
    ftype = "config"
    if "local/bin" in abs_path:
        ftype = "script"
    elif "Applications" in abs_path or abs_path.endswith(".AppImage"):
        ftype = "appimage"
    elif abs_path.endswith(".rpm"):
        ftype = "rpm"
    elif "fonts" in abs_path:
        ftype = "font"
    elif abs_path.startswith("/etc") or abs_path == "/etc/hosts":
        ftype = "system"
        
    pending["files"].append({
        "path": abs_path,
        "type": ftype,
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M")
    })
    save_pending(pending)
    console.print(f"[green]Added {abs_path} ({ftype}) to pending changes list.[/green]")

@app.command(rich_help_panel="Imports & Migration")
def log(msg: str = typer.Argument(None), pkg: str = typer.Option(None, "--pkg", help="Add package name to pending list")):
    """Add a manual changelog entry or manually log a package install/uninstall."""
    if pkg:
        # Expected format: "manager:package" or just "package" (defaults to dnf)
        mgr = "dnf"
        pname = pkg
        if ":" in pkg:
            mgr, pname = pkg.split(":", 1)
            
        pending = load_pending()
        if mgr not in pending["packages"]:
            pending["packages"][mgr] = []
            
        if pname not in pending["packages"][mgr]:
            pending["packages"][mgr].append(pname)
            save_pending(pending)
            console.print(f"[green]Logged package {pname} under {mgr} to pending queue.[/green]")
    elif msg:
        log_changelog("MANUAL", msg)
        console.print(f"[green]Added manual log entry: {msg}[/green]")
    else:
        console.print("[red]Error: Either MSG or --pkg must be provided.[/red]")
        raise typer.Exit(1)

@app.command("remove-pkg", rich_help_panel="Imports & Migration")
def remove_pkg(manager: str, name: str):
    """Log a package removal (removes from pending and from package list)."""
    # 1. Remove from pending
    pending = load_pending()
    if manager in pending["packages"] and name in pending["packages"][manager]:
        pending["packages"][manager].remove(name)
        save_pending(pending)
        console.print(f"[green]Removed {name} from {manager} pending queue.[/green]")
    
    # 2. Remove from final list
    list_file = os.path.join(PACKAGES_DIR, f"{manager}.txt")
    if os.path.exists(list_file):
        with open(list_file, "r") as f:
            existing = [line.strip() for line in f if line.strip()]
        if name in existing:
            existing.remove(name)
            with open(list_file, "w") as f:
                for p in existing:
                    f.write(f"{p}\n")
            console.print(f"[green]Removed {name} from {list_file}[/green]")
            log_changelog("UNINSTALLED", f"{name} ({manager})")

@app.command(rich_help_panel="Utility")
def restore():
    """Run bootstrap restoration (fresh install mode)."""
    console.print("[bold yellow]Initiating restoration/bootstrap...[/bold yellow]")
    if os.path.exists(bootstrap_script):
        subprocess.run(["bash", bootstrap_script])
    else:
        console.print("[red]Error: bootstrap.sh not found inside dotfiles directory.[/red]")

def load_github_credentials():
    github_token = ""
    github_username = ""
    
    # Try to load GitHub credentials from ~/Documents/api_keys.toml
    keys_path = os.path.expanduser("~/Documents/api_keys.toml")
    if os.path.exists(keys_path):
        try:
            import tomllib
            with open(keys_path, "rb") as f:
                keys_data = tomllib.load(f)
                github_token = keys_data.get("github_token", "")
                github_username = keys_data.get("github_username", "")
        except Exception:
            pass

    # Fallback to config.toml
    if not github_token:
        github_token = CONFIG.get("github", {}).get("token", "")
    if not github_username:
        github_username = CONFIG.get("github", {}).get("username", "")
        
    return github_token, github_username

def ensure_git_repo(repo_path):
    repo_name = os.path.basename(repo_path)
    
    # 1. Local git check / init
    git_exists = os.path.exists(os.path.join(repo_path, ".git"))
    if not git_exists:
        github_token, github_username = load_github_credentials()
        if not github_token:
            console.print(f"[yellow]Warning: Cannot auto-initialize Git/GitHub for '{repo_path}' - GitHub token missing in config.toml or ~/Documents/api_keys.toml[/yellow]")
            return False
            
        console.print(f"[cyan]Initializing local Git repository for '{repo_name}'...[/cyan]")
        try:
            subprocess.run(["git", "init"], cwd=repo_path, check=True)
            subprocess.run(["git", "branch", "-M", "main"], cwd=repo_path, check=True)
        except Exception as e:
            console.print(f"[red]Failed to initialize local Git repo: {e}[/red]")
            return False
            
    # 2. Remote check / configuration
    remote_proc = subprocess.run(["git", "remote", "get-url", "origin"], cwd=repo_path, capture_output=True, text=True)
    remote_url = remote_proc.stdout.strip()
    
    remote_exists = False
    if remote_url:
        ls_remote = subprocess.run(["git", "ls-remote", "origin"], cwd=repo_path, capture_output=True)
        if ls_remote.returncode == 0:
            remote_exists = True
            
    if not remote_url or not remote_exists:
        github_token, github_username = load_github_credentials()
        if not github_token:
            console.print(f"[yellow]Warning: Cannot auto-initialize Git/GitHub for '{repo_path}' - GitHub token missing in config.toml or ~/Documents/api_keys.toml[/yellow]")
            return False
            
        if remote_url and not remote_exists:
            console.print(f"[yellow]Warning: Remote configured but repository does not exist on GitHub. Re-initializing...[/yellow]")
            subprocess.run(["git", "remote", "remove", "origin"], cwd=repo_path, capture_output=True)
            
        console.print(f"[cyan]Configuring remote for '{repo_name}' with GitHub...[/cyan]")
        try:
            # Login/auth to gh CLI
            subprocess.run(
                f"echo {github_token} | gh auth login --with-token",
                shell=True,
                cwd=repo_path,
                check=True,
                capture_output=True
            )
            # Setup git credential helper
            subprocess.run(["gh", "auth", "setup-git"], cwd=repo_path, check=True, capture_output=True)
            
            # Create repo on GitHub
            console.print(f"[cyan]Creating private GitHub repository '{repo_name}'...[/cyan]")
            res = subprocess.run(
                ["gh", "repo", "create", repo_name, "--private", "--source=.", "--remote=origin"],
                cwd=repo_path,
                capture_output=True,
                text=True
            )
            
            if res.returncode != 0:
                # If creation failed (probably already exists), manually add remote URL using token
                console.print(f"[yellow]Warning: 'gh repo create' failed: {res.stderr.strip().splitlines()[0] if res.stderr else 'unknown error'}. Setting remote manually...[/yellow]")
                manual_url = f"https://{github_token}@github.com/{github_username}/{repo_name}.git"
                subprocess.run(["git", "remote", "remove", "origin"], cwd=repo_path, capture_output=True)
                subprocess.run(["git", "remote", "add", "origin", manual_url], cwd=repo_path, check=True)
                
            # Perform initial push of the branch to main
            subprocess.run(["git", "add", "."], cwd=repo_path)
            subprocess.run(["git", "commit", "-m", "initial commit"], cwd=repo_path, capture_output=True)
            subprocess.run(["git", "push", "-u", "origin", "main"], cwd=repo_path, capture_output=True)
            
            console.print(f"[green]Successfully configured remote for '{repo_name}' on GitHub.[/green]")
        except Exception as e:
            console.print(f"[red]Failed to setup remote for '{repo_name}' on GitHub: {e}[/red]")
            return False
            
    return True

def run_git_backup(dry_run=False, message=None):
    # Dotfiles repository backup
    # Check if dotfiles repo itself has modifications
    subprocess.run(["git", "add", "."], cwd=DOTFILES_DIR)
    diff_proc = subprocess.run(["git", "diff", "--cached", "--stat"], cwd=DOTFILES_DIR, capture_output=True, text=True)
    diff_summary = diff_proc.stdout.strip()
    
    if diff_summary:
        commit_msg = message or generate_commit_message(diff_summary)
        if not dry_run:
            subprocess.run(["git", "commit", "-m", commit_msg], cwd=DOTFILES_DIR)
            res = subprocess.run(["git", "push", "-u", "origin", "main"], cwd=DOTFILES_DIR, capture_output=True, text=True)
            if res.returncode == 0:
                console.print(f"[green]Pushed dotfiles repo: {commit_msg}[/green]")
            else:
                console.print(f"[red]Failed to push dotfiles repo: {res.stderr.strip()}[/red]")
        else:
            console.print(f"[yellow][Dry Run] Would commit dotfiles with: {commit_msg}[/yellow]")
    else:
        console.print("[green]Dotfiles repo is clean.[/green]")
        if not dry_run:
            subprocess.run(["git", "push", "-u", "origin", "main"], cwd=DOTFILES_DIR, capture_output=True)
        
    # Obsidian Vault
    obsidian_path = os.path.expanduser("~/Documents/vault")
    if os.path.exists(obsidian_path):
        if ensure_git_repo(obsidian_path):
            run_single_git_backup(obsidian_path, dry_run)
        
    # Additional configured repos
    extra_repos = CONFIG.get("backup", {}).get("repos", [])
    for repo_path_str in extra_repos:
        repo_path = os.path.abspath(os.path.expanduser(repo_path_str))
        if os.path.exists(repo_path):
            if ensure_git_repo(repo_path):
                run_single_git_backup(repo_path, dry_run)
                
    # Dev folders (all projects in ~/dev/ that don't start with a dot)
    dev_dir = os.path.expanduser(CONFIG["paths"].get("dev_dir", "~/dev"))
    if os.path.exists(dev_dir):
        for entry in os.scandir(dev_dir):
            if entry.is_dir() and not entry.name.startswith("."):
                if ensure_git_repo(entry.path):
                    run_single_git_backup(entry.path, dry_run)

def run_single_git_backup(repo_path, dry_run):
    # Check if repo has changes
    subprocess.run(["git", "add", "."], cwd=repo_path)
    diff_proc = subprocess.run(["git", "diff", "--cached", "--stat"], cwd=repo_path, capture_output=True, text=True)
    diff_summary = diff_proc.stdout.strip()
    
    if diff_summary:
        # Check config to see if Gemini is toggled for this repo
        # Standard configuration check
        gemini_enabled = CONFIG.get("gemini", {}).get("enabled", True)
        repo_overrides = CONFIG.get("gemini", {}).get("repos", {})
        
        # Check if this specific repo overrides it
        for override_path, val in repo_overrides.items():
            if os.path.abspath(os.path.expanduser(override_path)) == os.path.abspath(repo_path):
                gemini_enabled = val
                break
                
        # Generate message
        if gemini_enabled:
            commit_msg = generate_commit_message(diff_summary)
        else:
            commit_msg = f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"
            
        if not dry_run:
            subprocess.run(["git", "commit", "-m", commit_msg], cwd=repo_path)
            res = subprocess.run(["git", "push", "-u", "origin", "main"], cwd=repo_path, capture_output=True, text=True)
            if res.returncode == 0:
                console.print(f"[green]Pushed repo {os.path.basename(repo_path)}: {commit_msg}[/green]")
            else:
                console.print(f"[red]Failed to push repo {os.path.basename(repo_path)}: {res.stderr.strip()}[/red]")
        else:
            console.print(f"[yellow][Dry Run] Would commit {os.path.basename(repo_path)} with: {commit_msg}[/yellow]")
    else:
        if not dry_run:
            subprocess.run(["git", "push", "-u", "origin", "main"], cwd=repo_path, capture_output=True)

def run_heavy_backup():
    heavy_dest = CONFIG.get("backup", {}).get("heavy_dest", "")
    heavy_folders = CONFIG.get("backup", {}).get("heavy_folders", [])
    exclude_list = CONFIG.get("backup", {}).get("rsync_exclude", [])
    
    if not heavy_dest:
        console.print("[yellow]No heavy backup destination configured. Skipping.[/yellow]")
        return
        
    # Check if drive is mounted (by checking if path exists)
    if not os.path.exists(heavy_dest):
        console.print(f"[yellow]Heavy backup destination {heavy_dest} not mounted. Skipping gracefully.[/yellow]")
        return
        
    for folder in heavy_folders:
        src = os.path.abspath(os.path.expanduser(folder))
        if not os.path.exists(src):
            console.print(f"[yellow]Heavy backup source {src} does not exist. Skipping.[/yellow]")
            continue
            
        dest_folder_name = os.path.basename(src.rstrip("/"))
        dest = os.path.join(heavy_dest, dest_folder_name)
        
        # Construct rsync command
        cmd = ["rsync", "-avz", "--delete"]
        for exc in exclude_list:
            cmd.append(f"--exclude={exc}")
        cmd.extend([src + "/", dest])
        
        console.print(f"[cyan]Running rsync: {src} -> {dest}...[/cyan]")
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            console.print(f"[green]Rsync complete for {src}[/green]")
        else:
            console.print(f"[red]Rsync failed for {src}: {res.stderr}[/red]")

@app.command("import-configs", rich_help_panel="Imports & Migration")
def import_configs():
    """Scan watch paths for existing non-stowed configurations and import them."""
    console.print("[cyan]Scanning watch paths for existing non-stowed configurations...[/cyan]")
    watch_paths = CONFIG.get("watch", {}).get("paths", [])
    candidates = []
    
    for p in watch_paths:
        abs_path = os.path.abspath(os.path.expanduser(p))
        if not os.path.exists(abs_path):
            continue
            
        if os.path.isdir(abs_path):
            try:
                for entry in os.scandir(abs_path):
                    entry_path = entry.path
                    if is_ignored(entry_path):
                        continue
                    # Check if already a symlink pointing to stow
                    if os.path.islink(entry_path):
                        target = os.readlink(entry_path)
                        if STOW_DIR in os.path.abspath(target):
                            # Clean broken symlink if target doesn't exist
                            if not os.path.exists(entry_path):
                                console.print(f"[yellow]Found broken/dangling stow symlink: {entry_path}. Cleaning up...[/yellow]")
                                try:
                                    os.unlink(entry_path)
                                except Exception:
                                    subprocess.run(["sudo", "rm", "-f", entry_path])
                                continue
                            continue
                    candidates.append(entry_path)
            except Exception as e:
                console.print(f"[yellow]Warning: Failed to scan {abs_path}: {e}[/yellow]")
        else:
            if not is_ignored(abs_path):
                if os.path.islink(abs_path):
                    target = os.readlink(abs_path)
                    if STOW_DIR in os.path.abspath(target):
                        # Clean broken symlink if target doesn't exist
                        if not os.path.exists(abs_path):
                            console.print(f"[yellow]Found broken/dangling stow symlink: {abs_path}. Cleaning up...[/yellow]")
                            try:
                                os.unlink(abs_path)
                            except Exception:
                                subprocess.run(["sudo", "rm", "-f", abs_path])
                            continue
                        continue
                candidates.append(abs_path)
                
    if not candidates:
        console.print("[green]No unstowed configurations found in watch paths![/green]")
        return
        
    console.print(f"[bold]Found {len(candidates)} unstowed configurations.[/bold]\n")
    
    yes_to_all = False
    skip_all = False
    
    for idx, cand in enumerate(candidates):
        if skip_all:
            break
            
        console.print(Panel(f"[yellow]Unstowed Configuration ({idx+1}/{len(candidates)})[/yellow]\nPath: [bold]{cand}[/bold]"))
        
        if yes_to_all:
            ans = "y"
        else:
            ans = Prompt.ask(
                "Stow this configuration?",
                choices=["y", "n", "a", "s", "q"],
                default="y"
            ).lower()
            
        if ans == "q":
            break
        elif ans == "s":
            skip_all = True
            break
        elif ans == "a":
            yes_to_all = True
            ans = "y"
            
        if ans == "y":
            pkg = find_stow_package(cand)
            if not pkg:
                basename = os.path.basename(cand)
                if basename.startswith("."):
                    basename = basename[1:]
                pkg = Prompt.ask(f"Enter stow package name for '{os.path.basename(cand)}'", default=basename)
            if pkg:
                if stow_file(cand, pkg):
                    log_changelog("CONFIG", f"Imported {os.path.basename(cand)} into stow package {pkg}")

@app.command("import-packages", rich_help_panel="Imports & Migration")
def import_packages():
    """Scan manually installed DNF packages and import them to the tracked list."""
    console.print("[cyan]Querying manually installed DNF packages...[/cyan]")
    try:
        cmd = ["dnf", "repoquery", "--userinstalled", "--queryformat", "%{name}\n"]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode != 0:
            console.print(f"[red]Failed to query DNF: {res.stderr}[/red]")
            return
            
        installed = [line.strip() for line in res.stdout.split("\n") if line.strip()]
    except Exception as e:
        console.print(f"[red]Failed to run DNF: {e}[/red]")
        return
        
    list_file = os.path.join(PACKAGES_DIR, "dnf.txt")
    existing = []
    if os.path.exists(list_file):
        with open(list_file, "r") as f:
            existing = [line.strip() for line in f if line.strip() and not line.strip().startswith("#")]
            
    untracked = [p for p in installed if p not in existing]
    
    if not untracked:
        console.print("[green]All manually installed DNF packages are already tracked in dnf.txt![/green]")
        return
        
    console.print(f"[bold]Found {len(untracked)} manually installed packages not yet tracked in dnf.txt.[/bold]\n")
    from rich.columns import Columns
    console.print(Columns(untracked[:100], equal=True, expand=True))
    if len(untracked) > 100:
        console.print(f"... and {len(untracked) - 100} more packages.")
        
    ans = Prompt.ask(
        "\nTrack all of these packages? [y] Yes to all  [n] No  [i] Interactive selection  [q] Quit",
        choices=["y", "n", "i", "q"],
        default="y"
    ).lower()
    
    if ans == "q" or ans == "n":
        return
        
    to_add = []
    if ans == "y":
        to_add = untracked
    elif ans == "i":
        yes_to_all = False
        for idx, pkg in enumerate(untracked):
            if yes_to_all:
                to_add.append(pkg)
                continue
            ans_pkg = Prompt.ask(
                f"Track package {pkg} ({idx+1}/{len(untracked)})?",
                choices=["y", "n", "a", "q"],
                default="y"
            ).lower()
            if ans_pkg == "q":
                break
            elif ans_pkg == "a":
                yes_to_all = True
                to_add.append(pkg)
            elif ans_pkg == "y":
                to_add.append(pkg)
                
    if to_add:
        updated = sorted(list(set(existing + to_add)))
        with open(list_file, "w") as f:
            f.write("# dnf.txt - List of DNF packages to install during system restoration.\n")
            f.write("# Add package names here (one per line).\n")
            for p in updated:
                f.write(f"{p}\n")
        console.print(f"[green]Successfully added {len(to_add)} packages to {list_file}[/green]")
        for p in to_add:
            log_changelog("IMPORTED_PACKAGE", f"{p} (dnf)")

if __name__ == "__main__":
    app()
