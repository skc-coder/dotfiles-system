# Dotfiles Sentry

Personal Linux system backup and restore manager built in Python and managed with `uv`.

## Setup & Installation

```bash
git clone https://github.com/skc-coder/dotfiles-system.git
cd dotfiles-system
uv venv && source .venv/bin/activate
uv pip install -e .
```

## Running the Manager

```bash
python3 dotfiles.py status
python3 dotfiles.py backup
```

## Update & Sync

```bash
git pull && python3 dotfiles.py status
```
