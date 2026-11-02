#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PY'
import datetime
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

if len(sys.argv) > 2 or (len(sys.argv) == 2 and sys.argv[1] in {"-h", "--help"}):
    print(f"Usage: {Path(sys.argv[0]).name} [path/to/pringgadani.save]")
    print("Close the game before running this script.")
    raise SystemExit(0 if len(sys.argv) == 2 else 2)

if len(sys.argv) == 2:
    save_path = Path(sys.argv[1]).expanduser()
else:
    data_home = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    save_path = data_home / "godot" / "app_userdata" / "PringgadaniFortress" / "pringgadani.save"

if not save_path.is_file():
    raise SystemExit(f"Save file not found: {save_path}")

try:
    with save_path.open(encoding="utf-8") as save_file:
        data = json.load(save_file)
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"Could not read save file: {error}") from error

if not isinstance(data, dict):
    raise SystemExit("Save file must contain a JSON object; no changes made.")

backup_stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
backup_path = save_path.with_name(f"{save_path.name}.{backup_stamp}.bak")
try:
    shutil.copy2(save_path, backup_path)
    data["lives"] = 3
    data["last_life_loss_time"] = 0

    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            dir=save_path.parent,
            prefix=f".{save_path.name}.",
            suffix=".tmp",
            delete=False,
        ) as temp_file:
            temp_path = Path(temp_file.name)
            json.dump(data, temp_file, separators=(",", ":"))
            temp_file.flush()
            os.fsync(temp_file.fileno())
        os.chmod(temp_path, save_path.stat().st_mode)
        os.replace(temp_path, save_path)
    finally:
        if temp_path is not None and temp_path.exists():
            temp_path.unlink()
except OSError as error:
    raise SystemExit(f"Could not update save file: {error}") from error

print(f"Lives restored to 3 in {save_path}")
print(f"Backup saved to {backup_path}")
PY
