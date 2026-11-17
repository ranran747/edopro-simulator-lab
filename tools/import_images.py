"""Import EDOPro card art from a local folder or a user-supplied HTTPS TSV."""
import argparse
from collections import Counter
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener

ART_NAME = re.compile(r"([1-9][0-9]{0,9})\.(jpe?g|png)", re.IGNORECASE)
CARD_ID = re.compile(r"[1-9][0-9]{0,9}")
MAX_BYTES = 12 * 1024 * 1024


def image_extension(data):
    if data.startswith(b"\x89PNG\r\n\x1a\n") and data.endswith(b"IEND\xaeB`\x82"):
        return ".png"
    if data.startswith(b"\xff\xd8\xff") and data.endswith(b"\xff\xd9"):
        return ".jpg"
    raise ValueError("incomplete or unsupported image (expected PNG or JPEG)")


def validate_url(url, hosts):
    parts = urlsplit(url)
    if (parts.scheme != "https" or parts.hostname not in hosts or parts.username
            or parts.password or parts.port not in (None, 443) or parts.fragment):
        raise ValueError("use a direct HTTPS URL on an explicitly allowed host")


class CheckedRedirects(HTTPRedirectHandler):
    def __init__(self, hosts):
        self.hosts = hosts

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        validate_url(newurl, self.hosts)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def read_manifest(path, hosts):
    entries = {}
    for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 2 or not CARD_ID.fullmatch(parts[0]) or parts[0] in entries:
            raise ValueError(f"line {line_number}: expected a unique numeric ID and a URL")
        validate_url(parts[1], hosts)
        entries[parts[0]] = parts[1]
    return entries


def import_images(entries, pics, reader, wait):
    pics.mkdir(parents=True, exist_ok=True)
    results = Counter()
    for card_id, source in entries.items():
        if any((pics / (card_id + suffix)).exists() for suffix in (".jpg", ".jpeg", ".png")):
            results["kept"] += 1
            continue
        try:
            with reader(source) as stream:
                data = stream.read(MAX_BYTES + 1)
            if len(data) > MAX_BYTES:
                raise ValueError("image exceeds 12 MiB")
            dest = pics / (card_id + image_extension(data))
            with dest.open("xb") as output:
                output.write(data)
        except FileExistsError:
            results["kept"] += 1
        except (OSError, ValueError) as error:
            print(f"{card_id}: {error}", file=sys.stderr)
            results["failed"] += 1
            if isinstance(error, HTTPError) and error.code in (403, 429):
                print("Source denied access or requested a slower rate. Remaining IDs were skipped.", file=sys.stderr)
                break
        else:
            results["imported"] += 1
        if wait:
            time.sleep(wait)
    print(" ".join(f"{key}={results[key]}" for key in ("imported", "kept", "failed"))
          + f" unprocessed={len(entries) - results.total()}")
    return int(bool(results["failed"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--manifest", type=Path, help="TSV with unique numeric ID and direct HTTPS image URL")
    source.add_argument("--local", type=Path, help="directory containing numeric JPG or PNG filenames")
    parser.add_argument("--runtime", type=Path, required=True, help="path to the ProjectIgnis directory")
    parser.add_argument("--allow-host", action="append", default=[])
    args = parser.parse_args()
    if not args.runtime.is_dir():
        parser.error("--runtime must point to an existing directory")
    try:
        if args.manifest:
            hosts = {host.lower() for host in args.allow_host}
            if not hosts:
                parser.error("--manifest requires at least one --allow-host")
            entries = read_manifest(args.manifest, hosts)
            opener = build_opener(CheckedRedirects(hosts))

            def read_url(url):
                return opener.open(Request(url, headers={"User-Agent": "EDOPro-Simulator-Lab/0.1"}), timeout=20)

            return import_images(entries, args.runtime / "pics", read_url, 0.5)
        entries = {}
        for path in sorted(args.local.iterdir()):
            match = ART_NAME.fullmatch(path.name)
            if path.is_file() and match:
                if match[1] in entries:
                    raise ValueError(f"multiple source images for ID {match[1]}")
                entries[match[1]] = path
        return import_images(entries, args.runtime / "pics", lambda path: path.open("rb"), 0)
    except (OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
