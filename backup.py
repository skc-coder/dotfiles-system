import sys
from dotfiles import run_git_backup, run_heavy_backup, console

def main():
    console.print("[bold cyan]Scheduled Backup Triggered[/bold cyan]")
    try:
        console.print("[cyan]Running Git backups (Tier 1)...[/cyan]")
        run_git_backup(dry_run=False)
        console.print("[cyan]Running Heavy backups (Tier 2)...[/cyan]")
        run_heavy_backup()
        console.print("[bold green]Scheduled Backup successfully completed.[/bold green]")
    except Exception as e:
        console.print(f"[bold red]Scheduled Backup failed: {e}[/bold red]")
        sys.exit(1)

if __name__ == "__main__":
    main()
