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
    # Check basic ignore list
    ignore_substrings = [
        ".git", "__pycache__", ".pyc", "pending.json", "changelog.log",
        ".swp", ".tmp", ".obsidian", ".trash"
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
        if os.path.exists(dest_path):
            console.print(f"[yellow]Warning: Destination {dest_path} already exists. Merging/Replacing.[/yellow]")
            if os.path.isdir(dest_path) and os.path.isdir(file_path):
                # Move files recursively
                for root, dirs, files in os.walk(file_path):
                    rel_sub = os.path.relpath(root, file_path)
                    sub_dest = os.path.join(dest_path, rel_sub) if rel_sub != "." else dest_path
                    os.makedirs(sub_dest, exist_ok=True)
                    for f in files:
                        os.replace(os.path.join(root, f), os.path.join(sub_dest, f))
                # remove original dir
                os.rmdir(file_path)
            else:
                os.remove(dest_path)
                os.rename(file_path, dest_path)
        else:
            os.rename(file_path, dest_path)
            
        # Run stow
        cmd = ["stow", "-d", STOW_DIR, "-t", home, pkg_name]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            console.print(f"[green]Stowed {file_path} -> package '{pkg_name}'[/green]")
            return True
        else:
            console.print(f"[red]Stow failed: {res.stderr}[/red]")
            # Attempt to restore
            os.rename(dest_path, file_path)
            return False
    except Exception as e:
        console.print(f"[red]Failed to move and stow file: {e}[/red]")
        return False

# Git backup helper
def generate_commit_message(diff_summary):
    api_key = CONFIG.get("gemini", {}).get("api_key", "")
    enabled = CONFIG.get("gemini", {}).get("enabled", True)
    
    if not enabled or not api_key:
        return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"
        
    try:
        model = CONFIG.get("gemini", {}).get("model", "gemini-2.0-flash")
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
        res = httpx.post(url, json=payload, timeout=10.0)
        if res.status_code == 200:
            content = res.json()
            message = content["contents"][0]["parts"][0]["text"].strip()
            # Clean up backticks/quotes if AI wrapped it
            if message.startswith("`") and message.endswith("`"):
                message = message.strip("`")
            if "\n" in message:
                message = message.split("\n")[0]
            return message
    except Exception as e:
        console.print(f"[yellow]Warning: Gemini API failed ({e}). Falling back to default message.[/yellow]")
        
    return f"auto: {datetime.now().strftime('%Y-%m-%d %H:%M')} | system backup"

@app.command()
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
            # Either copy or log depending on config setting
            mode = CONFIG.get("appimage", {}).get("mode", "log_only")
            if mode == "backup_copy":
                appimages_dir = os.path.join(DOTFILES_DIR, "AppImages")
                os.makedirs(appimages_dir, exist_ok=True)
                dest = os.path.join(appimages_dir, os.path.basename(path))
                try:
                    import shutil
                    shutil.copy2(path, dest)
                    log_changelog("APPIMAGE", f"Copied {path} to AppImages backup")
                    console.print(f"[green]Copied AppImage to {dest}[/green]")
                except Exception as e:
                    console.print(f"[red]Failed to copy AppImage {path}: {e}[/red]")
            else:
                log_changelog("APPIMAGE", f"Logged AppImage path: {path}")
                
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
    
    # 2. After reviewing: commits and pushes accepted changes with a Gemini-generated commit message
    console.print("[cyan]Generating commit message and pushing accepted changes...[/cyan]")
    # Run git add and generate a commit message based on diff
    subprocess.run(["git", "add", "."], cwd=DOTFILES_DIR)
    
    diff_proc = subprocess.run(["git", "diff", "--cached", "--stat"], cwd=DOTFILES_DIR, capture_output=True, text=True)
    diff_summary = diff_proc.stdout.strip()
    
    if diff_summary:
        commit_msg = generate_commit_message(diff_summary)
        console.print(f"[green]Commit message: {commit_msg}[/green]")
        subprocess.run(["git", "commit", "-m", commit_msg], cwd=DOTFILES_DIR)
        # Push
        subprocess.run(["git", "push"], cwd=DOTFILES_DIR)
    else:
        console.print("[yellow]No actual changes to commit after review.[/yellow]")

@app.command()
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

@app.command()
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

@app.command()
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

@app.command()
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

@app.command("remove-pkg")
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

@app.command()
def restore():
    """Run bootstrap restoration (fresh install mode)."""
    console.print("[bold yellow]Initiating restoration/bootstrap...[/bold yellow]")
    bootstrap_script = os.path.join(DOTFILES_DIR, "bootstrap.sh")
    if os.path.exists(bootstrap_script):
        subprocess.run(["bash", bootstrap_script])
    else:
        console.print("[red]Error: bootstrap.sh not found inside dotfiles directory.[/red]")

def ensure_git_repo(repo_path):
    if os.path.exists(os.path.join(repo_path, ".git")):
        return True
        
    github_token = CONFIG.get("github", {}).get("token", "")
    github_username = CONFIG.get("github", {}).get("username", "")
    
    if not github_token:
        console.print(f"[yellow]Warning: Cannot auto-initialize Git/GitHub for '{repo_path}' - GitHub token missing in config.toml[/yellow]")
        return False
        
    repo_name = os.path.basename(repo_path)
    console.print(f"[cyan]Auto-initializing Git repository for '{repo_name}'...[/cyan]")
    
    try:
        # Initialize local git
        subprocess.run(["git", "init"], cwd=repo_path, check=True)
        subprocess.run(["git", "branch", "-M", "main"], cwd=repo_path, check=True)
        
        # Create GitHub repo
        from github import Github
        g = Github(github_token)
        user = g.get_user()
        
        console.print(f"[cyan]Creating private GitHub repository '{repo_name}'...[/cyan]")
        repo = user.create_repo(
            name=repo_name,
            private=True,
            description="Automatically created by dotfiles backup system"
        )
        
        # Set remote
        remote_url = repo.clone_url.replace("https://github.com/", f"https://{github_token}@github.com/")
        subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=repo_path, check=True)
        return True
    except Exception as e:
        console.print(f"[red]Failed to auto-initialize Git/GitHub for '{repo_path}': {e}[/red]")
        return False

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
            subprocess.run(["git", "push"], cwd=DOTFILES_DIR)
            console.print(f"[green]Pushed dotfiles repo: {commit_msg}[/green]")
        else:
            console.print(f"[yellow][Dry Run] Would commit dotfiles with: {commit_msg}[/yellow]")
    else:
        console.print("[green]Dotfiles repo is clean.[/green]")
        
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
            subprocess.run(["git", "push"], cwd=repo_path)
            console.print(f"[green]Pushed repo {os.path.basename(repo_path)}: {commit_msg}[/green]")
        else:
            console.print(f"[yellow][Dry Run] Would commit {os.path.basename(repo_path)} with: {commit_msg}[/yellow]")

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

@app.command("import-configs")
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
                            continue
                    candidates.append(entry_path)
            except Exception as e:
                console.print(f"[yellow]Warning: Failed to scan {abs_path}: {e}[/yellow]")
        else:
            if not is_ignored(abs_path):
                if os.path.islink(abs_path):
                    target = os.readlink(abs_path)
                    if STOW_DIR in os.path.abspath(target):
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

@app.command("import-packages")
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
