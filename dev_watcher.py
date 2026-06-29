import os
import sys
import argparse
import subprocess
from inotify_simple import INotify, flags
from github import Github

# Import config helpers
from dotfiles import load_config, DOTFILES_DIR

def get_watcher_config():
    config = load_config()
    dev_dir = os.path.abspath(os.path.expanduser(config["paths"].get("dev_dir", "~/dev")))
    token = config.get("github", {}).get("token", "")
    username = config.get("github", {}).get("username", "")
    return dev_dir, token, username

def initialize_github_repo(folder_path, token, username):
    if not token:
        print("Error: GitHub token not found in config.toml. Cannot create remote repository.", file=sys.stderr)
        return False
        
    folder_name = os.path.basename(folder_path)
    print(f"\n[Dev Watcher] Initializing repository for {folder_name}...")
    
    # Prompt public vs private
    privacy = ""
    while privacy not in ["public", "private"]:
        privacy = input("Should the GitHub repository be public or private? (public/private): ").strip().lower()
    
    is_private = (privacy == "private")
    
    try:
        # Create GitHub repo via API
        print(f"Connecting to GitHub as {username}...")
        g = Github(token)
        user = g.get_user()
        
        print(f"Creating {'private' if is_private else 'public'} repository '{folder_name}' on GitHub...")
        repo = user.create_repo(
            name=folder_name,
            private=is_private,
            description="Initial commit from local dev watcher"
        )
        
        # Local Git init
        print("Initializing local git repository...")
        subprocess.run(["git", "init"], cwd=folder_path)
        
        # Add all files (if any) and commit
        subprocess.run(["git", "add", "."], cwd=folder_path)
        subprocess.run(["git", "commit", "-m", "Initial commit"], cwd=folder_path)
        subprocess.run(["git", "branch", "-M", "main"], cwd=folder_path)
        
        # Add remote
        # We can construct the git URL with token or SSH. Let's use HTTPS with clone URL.
        # To make push seamless, we can set remote url using token:
        # https://<token>@github.com/<username>/<repo_name>.git
        remote_url = repo.clone_url.replace("https://github.com/", f"https://{token}@github.com/")
        subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=folder_path)
        
        # Push to main
        print("Pushing to GitHub...")
        subprocess.run(["git", "push", "-u", "origin", "main"], cwd=folder_path)
        print("\nSuccessfully initialized local and GitHub repository!")
        input("\nPress Enter to exit...")
        return True
    except Exception as e:
        print(f"\nFailed to create/push repository: {e}", file=sys.stderr)
        input("\nPress Enter to exit...")
        return False

def watch_dev_folder():
    dev_dir, token, username = get_watcher_config()
    if not os.path.exists(dev_dir):
        os.makedirs(dev_dir, exist_ok=True)
        
    inotify = INotify()
    # Watch CREATE events in the top level of dev_dir
    watch_flags = flags.CREATE | flags.MOVED_TO
    inotify.add_watch(dev_dir, watch_flags)
    
    print(f"Dev Watcher started. Watching {dev_dir} for new directories...")
    
    while True:
        try:
            events = inotify.read(timeout=1000)
            for event in events:
                full_path = os.path.join(dev_dir, event.name)
                
                # Check if it is a directory and not a git ignored folder
                if os.path.isdir(full_path) and not event.name.startswith("."):
                    # Check if already a git repository
                    if os.path.exists(os.path.join(full_path, ".git")):
                        continue
                        
                    print(f"New directory detected: {full_path}")
                    # Notify user with actions
                    cmd = [
                        "notify-send",
                        "-a", "dotfiles",
                        "--action=yes=Yes",
                        "--action=no=No",
                        "New Dev Folder",
                        f"Initialize Git repository for '{event.name}'?"
                    ]
                    
                    # Run notify-send in background thread so we don't block watcher
                    def handle_event(folder):
                        proc = subprocess.run(cmd, capture_output=True, text=True)
                        output = proc.stdout.strip()
                        if output == "yes":
                            script_path = os.path.abspath(__file__)
                            # Launch Interactive Terminal to prompt user public/private
                            subprocess.Popen([
                                "kitty",
                                "--class", "dotfiles-dev-init",
                                "-e", "python3", script_path, "--init", folder
                            ])
                            
                    import threading
                    threading.Thread(target=handle_event, args=(full_path,), daemon=True).start()
                    
        except KeyboardInterrupt:
            print("Stopping Dev Watcher.")
            break
        except Exception as e:
            print(f"Dev Watcher error: {e}", file=sys.stderr)
            time.sleep(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Watch dev folder or initialize new git repos")
    parser.add_argument("--init", help="Folder path to initialize as Git + GitHub repo")
    args = parser.parse_args()
    
    if args.init:
        dev_dir, token, username = get_watcher_config()
        initialize_github_repo(args.init, token, username)
    else:
        watch_dev_folder()
