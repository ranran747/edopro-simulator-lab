"""List missing artwork and install locally supplied backs or original placeholders."""

import argparse
from contextlib import closing
import csv
from io import BytesIO
import json
from pathlib import Path
import sqlite3
from tempfile import NamedTemporaryFile

from export_local_pack import PROFILES

TOOLS = Path(__file__).resolve().parent


def profile_for(name):
    packaged = TOOLS.parent / "profile.json"
    if packaged.is_file():
        profile = json.loads(packaged.read_text(encoding="utf-8"))
        if name and name != profile["id"]:
            raise ValueError(f"this kit is for {profile['id']}")
        return profile
    if not name:
        raise ValueError("specify --profile")
    profiles = json.loads((TOOLS / "release_profiles.json").read_text(encoding="utf-8"))
    return {"id": name, **profiles[name]}


def card_rows(runtime, profile):
    path = runtime / "expansions" / PROFILES[profile["id"]]
    if not path.is_file():
        raise ValueError(f"matching card database is missing: {path}")
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
        return db.execute("SELECT datas.id, COALESCE(texts.name, '') FROM datas "
                          "LEFT JOIN texts USING (id) ORDER BY datas.id").fetchall()


def inventory(runtime, profile, output):
    rows = card_rows(runtime, profile)
    existing = {p.stem for p in (runtime / "pics").glob("*")
                if p.is_file() and p.suffix.lower() in {".jpeg", ".jpg", ".png"}}
    missing = [(code, name) for code, name in rows if str(code) not in existing]
    with output.open("x", encoding="utf-8-sig", newline="") as file:
        writer = csv.writer(file, delimiter="\t")
        writer.writerow(("id", "name", "printing", "language", "image_url", "source_page"))
        writer.writerows((code, name, "", "", "", "") for code, name in missing)
    print(f"{output}: {len(missing)} of {len(rows)} rows missing art")


def save_image(image, path, replace=False):
    if not replace and path.exists():
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=path.parent, suffix=path.suffix, delete=False) as temp:
        staged = Path(temp.name)
    try:
        image.save(staged)
        if replace:
            staged.replace(path)
        else:
            try:
                path.hardlink_to(staged)
            except FileExistsError:
                pass
    finally:
        staged.unlink(missing_ok=True)


def draw_placeholder(size, accent, text="", *, landscape=False, title=False):
    from PIL import Image, ImageDraw, ImageFont

    w, h = size
    image = Image.new("RGB", size, "#141b28")
    draw = ImageDraw.Draw(image)
    for y in range(h):
        draw.line((0, y, w, y), fill=(15 + 13 * y // h, 23 + 20 * y // h, 36 + 22 * y // h))
    if landscape:
        for x in range(-h, w + h, 56):
            draw.line((x, h, x + h, 0), fill="#293647", width=1)
        if title:
            draw.line((w * 3 // 5, h, w, h // 4), fill=accent, width=2)
        return image
    draw.rounded_rectangle((16, 16, w - 17, h - 17), radius=20, outline="#3d4f63", width=2)
    x, y = w // 2, h // 2 - (30 if text else 0)
    for radius, color in ((65, "#3d4f63"), (47, accent), (25, "#3d4f63")):
        draw.polygon(((x, y - radius), (x + radius, y), (x, y + radius), (x - radius, y)),
                     outline=color, width=2)
    if text:
        draw.text((x, y + 104), text, font=ImageFont.load_default(size=23), fill="#e0e7ef", anchor="mm")
    return image


def theme(runtime, profile, *, official_back=None, resource_back=None, title=None, battle=None,
          title_logo=None, icon=None, scene_sleeve=False, fill=False):
    from PIL import Image, ImageDraw, ImageFont, ImageOps

    if resource_back and profile["id"] != "onepiece":
        raise ValueError("--resource-back is available for the onepiece profile")
    ids = {str(code) for code, _ in card_rows(runtime, profile)}
    textures = runtime / "textures"
    tcg = textures / "tcg"
    accent = profile["accent"]

    def write(paths, original, size, *, caption="", landscape=False, heading=False):
        if original:
            with Image.open(original) as source:
                oriented = ImageOps.exif_transpose(source).convert("RGB")
                if (oriented.width >= oriented.height) != landscape:
                    raise ValueError(f"unexpected image orientation: {original}")
                image = ImageOps.pad(oriented, size, color="#141b28")
        elif fill:
            image = draw_placeholder(size, accent, caption, landscape=landscape, title=heading)
        else:
            return
        for path in paths:
            save_image(image, path, replace=bool(original))

    card_size = (360, 500)
    cover_paths = [tcg / "cover.png", textures / "cover.png", textures / "cover2.png"]
    if scene_sleeve and not official_back:
        if not title:
            raise ValueError("--scene-sleeve needs --backgrounds or --title")
        with Image.open(title) as source:
            sleeve = ImageOps.fit(source.convert("RGB"), card_size, Image.Resampling.LANCZOS)
        draw = ImageDraw.Draw(sleeve)
        draw.rounded_rectangle((8, 8, 351, 491), radius=15, outline=accent, width=4)
        draw.rounded_rectangle((22, 391, 337, 475), radius=12, fill="#162130")
        draw.text((180, 420), profile["client"], font=ImageFont.load_default(size=30),
                  fill="white", anchor="mm")
        draw.text((180, 450), "FAN SLEEVE", font=ImageFont.load_default(size=13), fill=accent, anchor="mm")
        for path in cover_paths:
            save_image(sleeve, path, replace=True)
    else:
        write(cover_paths, official_back, card_size)
    write([tcg / "title.jpg"], title, (1280, 720), landscape=True, heading=True)
    write([tcg / "battle.jpg"], battle, (1280, 720), landscape=True)
    if profile["id"] == "onepiece":
        write([tcg / "don-back.png"], resource_back, card_size, caption="RESOURCE")
    if title_logo:
        with Image.open(title_logo) as source:
            logo = source.convert("RGBA")
            logo.thumbnail((1000, 400), Image.Resampling.LANCZOS)
            save_image(logo, tcg / "title-logo.png", replace=True)
    if icon:
        with Image.open(icon) as source:
            square = ImageOps.pad(source.convert("RGBA"), (256, 256), color=(0, 0, 0, 0))
            save_image(square, tcg / "AppIcon.ico", replace=True)
            save_image(square, textures / "AppIcon.png", replace=True)
    if fill:
        save_image(draw_placeholder(card_size, accent, "NO IMAGE"), textures / "unknown.jpg")
        for code, label in profile.get("markers", {}).items():
            pics = runtime / "pics"
            if code in ids and not any((pics / f"{code}{suffix}").exists() for suffix in (".jpg", ".jpeg", ".png")):
                save_image(draw_placeholder(card_size, accent, label), pics / f"{code}.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", choices=PROFILES)
    parser.add_argument("--runtime", type=Path, default=Path("runtime/ProjectIgnis"))
    commands = parser.add_subparsers(dest="command", required=True)
    listing = commands.add_parser("inventory", help="export missing art IDs to a new TSV")
    listing.add_argument("--output", type=Path, default=Path("missing-art.tsv"))
    assets = commands.add_parser("theme", help="import authorized local theme images or fill missing slots")
    assets.add_argument("--official-back", type=Path)
    assets.add_argument("--resource-back", type=Path)
    assets.add_argument("--title", type=Path)
    assets.add_argument("--battle", type=Path)
    assets.add_argument("--title-logo", type=Path)
    assets.add_argument("--icon", type=Path)
    assets.add_argument("--backgrounds", action="store_true", help="install this kit's location scene")
    assets.add_argument("--scene-sleeve", action="store_true", help="make a fan sleeve from the location scene")
    assets.add_argument("--fill", action="store_true")
    args = parser.parse_args()
    try:
        profile = profile_for(args.profile)
        if args.command == "inventory":
            inventory(args.runtime, profile, args.output)
        else:
            configured = args.runtime / "config/tcg-profile.conf"
            if configured.read_text(encoding="utf-8-sig").strip() != profile["id"]:
                raise ValueError("runtime profile differs from the selected kit")
            if not any((args.official_back, args.resource_back, args.title, args.battle, args.title_logo,
                        args.icon, args.backgrounds, args.scene_sleeve, args.fill)):
                raise ValueError("specify local artwork, --backgrounds, or --fill")
            scene = TOOLS.parent / "artwork" / f"{profile['id']}.jpg" if args.backgrounds else None
            theme(args.runtime, profile, official_back=args.official_back, resource_back=args.resource_back,
                  title=args.title or scene, battle=args.battle or scene,
                  title_logo=args.title_logo, icon=args.icon, scene_sleeve=args.scene_sleeve, fill=args.fill)
            print(f"Theme updated for {profile['id']}")
    except ImportError:
        parser.error("theme needs Pillow. Run: python -m pip install Pillow")
    except (OSError, ValueError, sqlite3.Error) as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
