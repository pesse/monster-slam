"""Find broad paving areas along the standard Monster Slam detail-map route.

Tuned for the 1672x941 access3-style route; inspect the numbered overlay when
artwork or route layout changes. Requires Pillow and NumPy. The final arena
counts as one of the six areas; off-route plazas do not.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter


ROUTE = [
    (180, 770), (395, 690), (590, 640), (740, 520),
    (890, 450), (1190, 380), (1380, 255), (1450, 125),
]


def components(mask: np.ndarray) -> list[tuple[int, int, int]]:
    seen = np.zeros(mask.shape, dtype=bool)
    height, width = mask.shape
    result = []
    for y, x in zip(*np.nonzero(mask)):
        if seen[y, x]:
            continue
        todo = deque([(int(y), int(x))])
        seen[y, x] = True
        area = sx = sy = 0
        while todo:
            cy, cx = todo.popleft()
            area += 1
            sx += cx
            sy += cy
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                ny, nx = cy + dy, cx + dx
                if 0 <= ny < height and 0 <= nx < width and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    todo.append((ny, nx))
        if area >= 500:
            result.append((sx // area, sy // area, area))
    return result


def find_waypoints(
    path: Path,
    overlay: Path | None = None,
    route: list[tuple[int, int]] | None = None,
) -> list[tuple[int, int, int]]:
    image = Image.open(path).convert("RGB")
    if image.size != (1672, 941):
        raise ValueError(f"Expected 1672x941, got {image.size}")
    rgb = np.asarray(image).astype(np.int16)
    red, green, blue = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    pale = (
        (red > 195) & (green > 165) & (blue > 125)
        & (red - green < 75) & (green - blue < 75)
    )
    small = Image.fromarray((pale * 255).astype("uint8")).resize((836, 471), Image.Resampling.BILINEAR)
    small = small.point(lambda value: 255 if value > 130 else 0)
    route_mask = Image.new("L", small.size)
    drawer = ImageDraw.Draw(route_mask)
    drawer.line([(x // 2, y // 2) for x, y in (route or ROUTE)], fill=255, width=70, joint="curve")
    small = Image.fromarray(np.minimum(np.asarray(small), np.asarray(route_mask)))
    # Close paving seams, then erase the narrow path while retaining wide pads.
    wide = small.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(5))
    wide = wide.filter(ImageFilter.MinFilter(15)).filter(ImageFilter.MaxFilter(15))
    found = [(x * 2, y * 2, area) for x, y, area in components(np.asarray(wide) > 0)]
    found.sort(key=lambda item: item[0])
    if overlay:
        preview = image.copy()
        draw = ImageDraw.Draw(preview)
        for number, (x, y, _) in enumerate(found, 1):
            draw.ellipse((x - 14, y - 14, x + 14, y + 14), fill="red", outline="white", width=3)
            draw.text((x - 4, y - 7), str(number), fill="white")
        preview.save(overlay)
    return found


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--overlay-dir", type=Path)
    parser.add_argument("--expected", type=int, default=6)
    parser.add_argument("--route-json", type=Path, help="JSON array of [x,y] route points for a different layout")
    args = parser.parse_args()
    route = None
    if args.route_json:
        points = json.loads(args.route_json.read_text(encoding="utf-8"))
        if len(points) < 2 or any(len(point) != 2 for point in points):
            parser.error("--route-json needs at least two [x,y] points")
        route = [tuple(map(int, point)) for point in points]
    if args.overlay_dir:
        args.overlay_dir.mkdir(parents=True, exist_ok=True)
    failed = False
    for path in args.images:
        overlay = args.overlay_dir / path.name if args.overlay_dir else None
        found = find_waypoints(path, overlay, route)
        status = "OK" if len(found) == args.expected else "FAIL"
        print(f"{status} {path.name}: {len(found)} areas: {[(x, y) for x, y, _ in found]}")
        failed |= len(found) != args.expected
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
