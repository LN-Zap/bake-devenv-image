#!/usr/bin/env bash
set -euo pipefail

base_env="$(mktemp)"
devenv_env="$(mktemp)"
trap 'rm -f "$base_env" "$devenv_env"' EXIT

env | sort > "$base_env"
devenv shell -- env | sort > "$devenv_env"

BASE_ENV_FILE="$base_env" DEVENV_ENV_FILE="$devenv_env" python3 - <<'PY'
from __future__ import annotations

import os
import shlex
from pathlib import Path


def parse_env(path: str) -> dict[str, str]:
  parsed: dict[str, str] = {}
  with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
      line = line.rstrip("\n")
      if not line or "=" not in line:
        continue
      key, value = line.split("=", 1)
      parsed[key] = value
  return parsed


base_env = parse_env(os.environ["BASE_ENV_FILE"])
devenv_env = parse_env(os.environ["DEVENV_ENV_FILE"])

base_path = [entry for entry in base_env.get("PATH", "").split(":") if entry]
devenv_path = [entry for entry in devenv_env.get("PATH", "").split(":") if entry]
path_additions = [entry for entry in devenv_path if entry not in base_path]

excluded = {
  "PATH",
  "PWD",
  "OLDPWD",
  "SHLVL",
  "_",
}


def should_exclude(key: str) -> bool:
  if key in excluded:
    return True
  return key.startswith("GITHUB_") or key.startswith("RUNNER_")


changed_env: dict[str, str] = {}
for key, value in devenv_env.items():
  if should_exclude(key):
    continue
  if base_env.get(key) == value:
    continue
  changed_env[key] = value

output_path = Path(os.environ["ACTIVATION_SCRIPT_PATH"])
lines: list[str] = [
  "#!/usr/bin/env bash",
  "set -euo pipefail",
  "if [ -z \"${GITHUB_ENV:-}\" ] || [ -z \"${GITHUB_PATH:-}\" ]; then",
  "  echo 'GITHUB_ENV and GITHUB_PATH must be set' >&2",
  "  exit 1",
  "fi",
  "",
]

for entry in path_additions:
  lines.append(f"echo {shlex.quote(entry)} >> \"$GITHUB_PATH\"")

if path_additions:
  lines.append("")

for key in sorted(changed_env):
  value = changed_env[key]
  delimiter = f"__COPILOT_ENV_{key}__"
  lines.extend(
    [
      f"cat <<'EOF' >> \"$GITHUB_ENV\"",
      f"{key}<<{delimiter}",
      value,
      delimiter,
      "EOF",
    ]
  )

output_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
output_path.chmod(0o755)
PY

size_of() {
  local target="$1"
  if [ -e "$target" ]; then
    du -sb "$target" | awk '{print $1}'
  else
    echo 0
  fi
}

cache_bytes_removed=0

while IFS= read -r cache_path; do
  [ -z "$cache_path" ] && continue
  cache_size=$(size_of "$cache_path")
  cache_bytes_removed=$((cache_bytes_removed + cache_size))
  echo "Configured cache path size before slim (bytes): $cache_path => $cache_size"

  if [ "$SLIM_CACHES" = "true" ]; then
    rm -rf "$cache_path"
  fi
done <<< "$CACHE_PATHS"

if [ "$SLIM_CACHES" = "true" ]; then
  nix store optimise || true
fi

echo "Approx cache bytes removed before snapshot: $cache_bytes_removed"

activation_script_written="no"
if [ -x "$ACTIVATION_SCRIPT_PATH" ]; then
  activation_script_written="yes"
fi

{
  echo "activation_script_written=$activation_script_written"
  echo "cache_bytes_removed=$cache_bytes_removed"
  echo "snapshot_name=$SNAPSHOT_NAME"
} >> "$GITHUB_OUTPUT"
