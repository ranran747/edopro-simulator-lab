"""Text-only synthetic entry names; no actual image bytes are generated."""
import contextlib
import hashlib
from io import BytesIO, StringIO
import json
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch
from zipfile import ZipFile
import check_no_images as gate


def zipped(entries):
    buffer = BytesIO()
    with ZipFile(buffer, "w") as z:
        for name, data in entries:
            z.writestr(name, data)
    buffer.seek(0)
    return buffer


class GateTests(unittest.TestCase):
    def allow(self, scope, path, data=b"text-only fixture", **extra):
        return {(scope, path): {"scope": scope, "path": path, "role": "background",
                                "sha256": hashlib.sha256(data).hexdigest(), **extra}}

    def test_extensions_are_case_insensitive_and_not_text_mentions(self):
        self.assertTrue(gate.is_image_name("pics\\123.PnG"))
        self.assertTrue(gate.is_image_name("UI/Logo.SVG"))
        self.assertFalse(gate.is_image_name("docs/image.png.md"))

    def test_clean_zip(self):
        f, e = [], []
        gate.scan_zip(zipped([("docs/README.md", b"Reference: card.png"), ("script/a.lua", b"return 1")]), "fixture", f, e)
        self.assertEqual((f, e), ([], []))

    def test_nested_zip_detects_image_filename(self):
        nested = zipped([("pics/123.JpG", b"text fixture only")])
        f, e = [], []
        gate.scan_zip(zipped([("pack.zip", nested.getvalue())]), "fixture", f, e)
        self.assertEqual(f[0]["path"], "fixture!pack.zip!pics/123.JpG")
        self.assertFalse(e)

    def test_incomplete_nested_archive_does_not_pass(self):
        f, e = [], []
        gate.scan_zip(zipped([("vendor.zip", b"not a zip")]), "fixture", f, e)
        self.assertTrue(e)

    def test_index_scan_and_exit_codes(self):
        with patch.object(gate, "git_paths", return_value=["artwork/a.jpg", "docs/a.md"]) as paths, contextlib.redirect_stdout(StringIO()) as output:
            self.assertEqual(gate.main(["--repo", ".", "--index"]), 1)
            self.assertEqual(json.loads(output.getvalue())["image_count"], 1)
            paths.assert_called_once_with(Path("."), "HEAD", True)

    def test_exact_zip_background_path_and_hash_are_allowed(self):
        data = b"text-only fixture"
        f, e, a = [], [], []
        gate.scan_zip(zipped([("kit/artwork/scene.jpg", data)]), "fixture", f, e,
                      allowlist=self.allow("zip", "kit/artwork/scene.jpg", data), allowed_items=a)
        self.assertEqual((f, e), ([], []))
        self.assertEqual(len(a), 1)

    def test_changed_hash_is_not_allowed(self):
        f, e = [], []
        gate.scan_zip(zipped([("kit/artwork/scene.jpg", b"changed fixture")]), "fixture", f, e,
                      allowlist=self.allow("zip", "kit/artwork/scene.jpg"))
        self.assertEqual(f[0]["reason"], "sha256_mismatch")

    def test_same_hash_at_different_path_is_not_allowed(self):
        f, e = [], []
        gate.scan_zip(zipped([("other/artwork/scene.jpg", b"text-only fixture")]), "fixture", f, e,
                      allowlist=self.allow("zip", "kit/artwork/scene.jpg"))
        self.assertEqual(f[0]["reason"], "not_allowlisted")

    def test_manifest_rejects_globs_and_pics_and_card_face_role(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "allow.json"
            for target, role in [("*.png", "background"), ("runtime/ProjectIgnis/pics/123.png", "sleeve"),
                                 ("artwork/scene.jpg", "card_face")]:
                path.write_text(json.dumps({"version": 1, "allowed": [{"scope": "zip", "path": target,
                    "sha256": "a" * 64, "role": role}]}), encoding="utf-8")
                with self.assertRaises(ValueError):
                    gate.load_allowlist(path)

    def test_git_index_hash_is_read_from_index_not_worktree(self):
        data = b"text-only fixture"
        with patch.object(gate, "git_paths", return_value=["artwork/scene.jpg"]), \
             patch.object(gate, "git_blob", return_value=data) as blob, \
             patch.object(gate, "load_allowlist", return_value=self.allow("git", "artwork/scene.jpg", data)), \
             contextlib.redirect_stdout(StringIO()) as output:
            self.assertEqual(gate.main(["--repo", ".", "--index", "--allowlist", "allow.json"]), 0)
            self.assertEqual(json.loads(output.getvalue())["allowed_image_count"], 1)
            blob.assert_called_once_with(Path("."), "artwork/scene.jpg", "HEAD", True)

    def test_archive_root_is_explicit_and_never_inferred(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "allow.json"
            path.write_text(json.dumps({"version": 1, "allowed": list(self.allow("zip", "artwork/scene.jpg").values())}), encoding="utf-8")
            self.assertIn(("zip", "artwork/scene.jpg"), gate.load_allowlist(path))
            self.assertIn(("zip", "kit/artwork/scene.jpg"), gate.load_allowlist(path, "kit"))

    def test_git_exception_does_not_authorize_zip_image(self):
        f, e = [], []
        gate.scan_zip(zipped([("artwork/scene.jpg", b"text-only fixture")]), "fixture", f, e,
                      allowlist=self.allow("git", "artwork/scene.jpg"))
        self.assertEqual(f[0]["reason"], "not_allowlisted")


if __name__ == "__main__":
    unittest.main()
