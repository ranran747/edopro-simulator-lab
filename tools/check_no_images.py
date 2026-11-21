"""Read-only image-filename gate, with exact-path/SHA background/sleeve exceptions.

No downloads, extraction, deletion, git add/commit or publishing. Exit 0=clean,
1=image entries, 2=incomplete inspection/error. Scope is filenames, not images
embedded in executables, PDFs, databases, HTML/base64 or extensionless blobs.
"""
import argparse
import hashlib
from io import BytesIO
import json
from pathlib import Path, PurePosixPath
import re
import subprocess
from zipfile import BadZipFile, ZipFile

IMAGE_EXTENSIONS = frozenset(".png .jpg .jpeg .jpe .jfif .webp .gif .apng .bmp .dib .dds .svg .svgz .ico .icns .cur .tga .tif .tiff .avif .heif .heic .jxl .ktx .ktx2 .psd .kra .xcf .jp2 .j2k .jpf .jpx .jpm .pnm .ppm .pgm .pbm .qoi .exr .hdr".split())
OTHER_ARCHIVES = (".7z", ".rar", ".tar", ".tgz", ".tar.gz", ".tar.bz2", ".tar.xz")


def is_image_name(name):
    return PurePosixPath(name.replace("\\", "/")).suffix.casefold() in IMAGE_EXTENSIONS


def canonical_path(value):
    if not isinstance(value, str) or not value:
        raise ValueError("allowlist path must be a nonempty relative path")
    path = value.replace("\\", "/")
    pieces = re.split(r"[/!]", path)
    if path.startswith("/") or ":" in path or any(x in ("", ".", "..") for x in pieces) or any(c in path for c in "*?[]"):
        raise ValueError("allowlist requires an exact relative path; no glob/absolute/traversal path")
    return path


def load_allowlist(path, archive_root=None):
    if path is None:
        return {}
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict) or value.get("version") != 1 or not isinstance(value.get("allowed"), list):
        raise ValueError("allowlist schema: version=1 and allowed=[{scope,path,sha256,role}]")
    prefix = canonical_path(archive_root) + "/" if archive_root else ""
    result = {}
    for item in value["allowed"]:
        if not isinstance(item, dict) or item.get("scope") not in {"git", "zip"} or item.get("role") not in {"background", "sleeve"}:
            raise ValueError("allowlist permits only git/zip scope and background/sleeve role")
        target = canonical_path(item.get("path"))
        parts = [p.casefold() for p in re.split(r"[/!]", target)]
        if any(p in {"pics", "card-art", "card-images"} for p in parts) or PurePosixPath(target).stem.isdecimal():
            raise ValueError("card faces/pics/numeric artwork are never allowlisted")
        if not is_image_name(target):
            raise ValueError("allowlist target must have an image extension")
        digest = item.get("sha256", "")
        if not isinstance(digest, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", digest):
            raise ValueError("allowlist requires a complete SHA-256")
        if "bytes" in item and (type(item["bytes"]) is not int or item["bytes"] < 0):
            raise ValueError("allowlist bytes must be a nonnegative integer")
        target = prefix + target if item["scope"] == "zip" else target
        key = (item["scope"], target)
        if key in result:
            raise ValueError("duplicate allowlist scope/path")
        result[key] = {**item, "path": target, "sha256": digest.lower()}
    return result


def git_blob(repo, path, ref="HEAD", index=False):
    spec = ":" + path if index else ref + ":" + path
    result = subprocess.run(["git", "-C", str(repo), "cat-file", "blob", spec], capture_output=True, check=False)
    if result.returncode:
        raise ValueError("unable to read image blob from the selected Git ref/index")
    return result.stdout


def permitted_image(scope, path, reader, allowlist, allowed_items):
    entry = (allowlist or {}).get((scope, path))
    if entry is None:
        return False, "not_allowlisted"
    data = reader()
    if hashlib.sha256(data).hexdigest() != entry["sha256"]:
        return False, "sha256_mismatch"
    if "bytes" in entry and len(data) != entry["bytes"]:
        return False, "byte_count_mismatch"
    if allowed_items is not None:
        allowed_items.append({"source": scope, "path": path, "sha256": entry["sha256"], "role": entry["role"]})
    return True, None


def git_paths(repo, ref="HEAD", index=False):
    command = ["git", "-C", str(repo)]
    command += ["ls-files", "--cached", "-z"] if index else ["ls-tree", "-r", "--name-only", "-z", ref]
    result = subprocess.run(command, capture_output=True, check=False)
    if result.returncode:
        raise ValueError("git inventory failed; confirm repository/ref (no credentials are read)")
    return [p.decode("utf-8", "surrogateescape") for p in result.stdout.split(b"\0") if p]


def scan_zip(source, label, findings, errors, *, depth=0, max_depth=3,
             max_nested_bytes=256 * 1024 * 1024, budget=None, allowlist=None,
             allowed_items=None, logical_prefix=""):
    budget = budget if budget is not None else [max_nested_bytes]
    try:
        with ZipFile(source) as archive:
            for entry in archive.infolist():
                if entry.is_dir():
                    continue
                name = entry.filename.replace("\\", "/")
                qualified = label + "!" + name
                logical = logical_prefix + name
                if is_image_name(name):
                    valid, reason = permitted_image("zip", logical, lambda: archive.read(entry), allowlist, allowed_items)
                    if not valid:
                        findings.append({"source": "zip", "path": qualified, "reason": reason})
                if name.casefold().endswith(".zip"):
                    if depth >= max_depth or entry.file_size > budget[0]:
                        errors.append({"path": qualified, "error": "nested ZIP exceeds inspection depth/byte budget"})
                        continue
                    if entry.flag_bits & 1:
                        errors.append({"path": qualified, "error": "encrypted nested ZIP cannot be inspected"})
                        continue
                    budget[0] -= entry.file_size
                    scan_zip(BytesIO(archive.read(entry)), qualified, findings, errors,
                             depth=depth + 1, max_depth=max_depth,
                             max_nested_bytes=max_nested_bytes, budget=budget,
                             allowlist=allowlist, allowed_items=allowed_items,
                             logical_prefix=logical + "!")
                elif name.casefold().endswith(OTHER_ARCHIVES):
                    errors.append({"path": qualified, "error": "non-ZIP nested archive requires separate inspection"})
    except (OSError, ValueError, RuntimeError, BadZipFile) as error:
        errors.append({"path": label, "error": type(error).__name__ + ": unable to inspect ZIP"})


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, help="Git repository to inspect; omitted means ZIP-only")
    parser.add_argument("--ref", default="HEAD", help="Git ref; default HEAD")
    parser.add_argument("--index", action="store_true", help="inspect index paths instead of ref")
    parser.add_argument("--zip", dest="zips", action="append", type=Path, default=[])
    parser.add_argument("--allowlist", type=Path, help="version=1 exact scope/path/SHA background/sleeve JSON")
    parser.add_argument("--archive-root", help="explicitly prepend this root to ZIP allowlist paths; no automatic root stripping")
    parser.add_argument("--max-depth", type=int, default=3)
    parser.add_argument("--max-nested-mib", type=int, default=256)
    args = parser.parse_args(argv)
    if not args.repo and not args.zips:
        parser.error("provide --repo and/or --zip")
    if args.max_depth < 0 or args.max_nested_mib <= 0:
        parser.error("depth must be nonnegative and nested size must be positive")
    findings, errors, allowed_items = [], [], []
    try:
        allowlist = load_allowlist(args.allowlist, args.archive_root)
    except (OSError, ValueError, TypeError) as error:
        print(json.dumps({"ok": False, "incomplete_count": 1, "error": str(error)}, ensure_ascii=True))
        return 2
    if args.repo:
        try:
            for path in git_paths(args.repo, args.ref, args.index):
                if is_image_name(path):
                    valid, reason = permitted_image("git", path, lambda: git_blob(args.repo, path, args.ref, args.index), allowlist, allowed_items)
                    if not valid:
                        findings.append({"source": "git-index" if args.index else "git-ref:" + args.ref, "path": path, "reason": reason})
        except (OSError, ValueError) as error:
            errors.append({"path": str(args.repo), "error": str(error)})
    for path in args.zips:
        scan_zip(path, str(path), findings, errors, max_depth=args.max_depth,
                 max_nested_bytes=args.max_nested_mib * 1024 * 1024,
                 allowlist=allowlist, allowed_items=allowed_items)
    code = 2 if errors else (1 if findings else 0)
    print(json.dumps({"ok": code == 0, "scope": "image file extensions in Git paths and ZIP entries",
                      "image_count": len(findings), "images": findings,
                      "allowed_image_count": len(allowed_items), "allowed_images": allowed_items,
                      "incomplete_count": len(errors), "incomplete": errors}, ensure_ascii=True, indent=2))
    return code


if __name__ == "__main__":
    raise SystemExit(main())
