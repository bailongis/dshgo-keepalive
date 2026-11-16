#!/usr/bin/env python3
"""Build the flashable module zip (scripts + WebUI + default config)."""
import os
import re
import zipfile

ROOT = os.path.dirname(os.path.abspath(__file__))
TOP_FILES = ("module.prop", "service.sh", "control.sh", "config.conf", "uninstall.sh")
EXEC_FILES = {"service.sh", "control.sh", "uninstall.sh"}


def main():
    with open(os.path.join(ROOT, "module.prop"), encoding="utf-8") as f:
        text = f.read()
    version = re.search(r"^version=(.+)$", text, re.M).group(1).strip()
    out = os.path.join(ROOT, f"dsh-keepalive-{version}.zip")

    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for name in TOP_FILES:
            path = os.path.join(ROOT, name)
            info = zipfile.ZipInfo(name)
            info.external_attr = (0o755 if name in EXEC_FILES else 0o644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, open(path, "rb").read())

        webroot = os.path.join(ROOT, "webroot")
        for dirpath, dirnames, filenames in os.walk(webroot):
            dirnames.sort()
            rel_dir = os.path.relpath(dirpath, ROOT).replace(os.sep, "/")
            if rel_dir != "webroot":
                info = zipfile.ZipInfo(rel_dir + "/")
                info.external_attr = (0o755 | 0o040000) << 16
                z.writestr(info, b"")
            for filename in sorted(filenames):
                path = os.path.join(dirpath, filename)
                rel = os.path.relpath(path, ROOT).replace(os.sep, "/")
                info = zipfile.ZipInfo(rel)
                info.external_attr = 0o644 << 16
                info.compress_type = zipfile.ZIP_DEFLATED
                z.writestr(info, open(path, "rb").read())

    print(f"built {out} ({os.path.getsize(out)} bytes)")


if __name__ == "__main__":
    main()
