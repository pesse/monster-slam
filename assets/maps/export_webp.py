"""Export map PNG sources as 1920 x 1080 WebP images below 2 MB."""

from __future__ import annotations

from io import BytesIO
from pathlib import Path

from PIL import Image, features


ROOT = Path(__file__).resolve().parent
TARGET = (1920, 1080)
LIMIT = 2_000_000


def main():
    if not features.check("webp"):
        raise RuntimeError("Pillow was built without WebP support")
    for access in (2, 3, 4):
        folder = ROOT / f"access{access}"
        for source in sorted(folder.glob("*.png")):
            if source.stem != "book" and not source.stem.startswith("unit"):
                continue
            with Image.open(source) as original:
                image = original.convert("RGB")
                if image.size == (1536, 1024):
                    image = image.crop((0, 80, 1536, 944))
                image = image.resize(TARGET, Image.Resampling.LANCZOS)
            for quality in (88, 84, 80, 76, 72, 68):
                buffer = BytesIO()
                image.save(buffer, format="WEBP", quality=quality, method=6)
                if buffer.tell() < LIMIT:
                    destination = source.with_suffix(".webp")
                    destination.write_bytes(buffer.getvalue())
                    print(f"{destination}: {buffer.tell():,} bytes, quality {quality}")
                    break
            else:
                raise RuntimeError(f"Cannot get below 2 MB: {source}")


if __name__ == "__main__":
    main()
