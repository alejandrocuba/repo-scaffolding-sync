#!/usr/bin/env python3
import json
import os
import sys

def detect_indent(content):
    for line in content.splitlines():
        if line.startswith("  ") and not line.startswith("   "):
            return 2
        elif line.startswith("    "):
            return 4
    return 2

def main():
    if len(sys.argv) < 2:
        print("Usage: merge-package-json.py <path_to_package.json>")
        sys.exit(1)

    pkg_path = sys.argv[1]
    if not os.path.isfile(pkg_path):
        print(f"File not found: {pkg_path}")
        sys.exit(0)

    with open(pkg_path, "r", encoding="utf-8") as f:
        content = f.read()

    indent = detect_indent(content)
    try:
        data = json.loads(content)
    except Exception as e:
        print(f"Error parsing {pkg_path}: {e}")
        sys.exit(1)

    changed = False

    # 1. Ensure scripts.prepare is present
    if "scripts" not in data or not isinstance(data["scripts"], dict):
        data["scripts"] = {}
        changed = True

    if "prepare" not in data["scripts"]:
        data["scripts"]["prepare"] = "husky"
        changed = True

    # 2. Ensure devDependencies have husky and commitlint
    if "devDependencies" not in data or not isinstance(data["devDependencies"], dict):
        data["devDependencies"] = {}
        changed = True

    required_dev_deps = {
        "@commitlint/cli": "^21.2.2",
        "@commitlint/config-conventional": "^21.2.2",
        "husky": "^9.1.7"
    }

    for dep, ver in required_dev_deps.items():
        if dep not in data["devDependencies"]:
            data["devDependencies"][dep] = ver
            changed = True

    # Sort devDependencies alphabetically for consistency if modified
    if changed:
        data["devDependencies"] = dict(sorted(data["devDependencies"].items()))
        with open(pkg_path, "w", encoding="utf-8") as f:
            f.write(json.dumps(data, indent=indent, ensure_ascii=False) + "\n")
        print(f"MODIFIED: Successfully merged husky and commitlint into {pkg_path}")
    else:
        print(f"UNCHANGED: {pkg_path} already configured")

if __name__ == "__main__":
    main()
