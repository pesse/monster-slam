"""Check Monster Slam route metadata and render an overlay for visual review.

With --route-json, validates the image size, ordered stops and path spacing.
Without metadata, uses a legacy paving detector calibrated on 1672x941 maps.
Requires Pillow and NumPy.
"""

from __future__ import annotations

import argparse
import json
import math
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
        original_size = image.size
        image = image.resize((1672, 941), Image.Resampling.LANCZOS)
        if route:
            route = [(round(x * 1672 / original_size[0]), round(y * 941 / original_size[1]))
                     for x, y in route]
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


def distance_to_path(point, path):
    best = float("inf")
    for a, b in zip(path, path[1:]):
        dx, dy = b[0] - a[0], b[1] - a[1]
        length_sq = dx * dx + dy * dy
        fraction = max(0, min(1, ((point[0] - a[0]) * dx + (point[1] - a[1]) * dy)
                              / length_sq)) if length_sq else 0
        projected = (a[0] + fraction * dx, a[1] + fraction * dy)
        best = min(best, math.dist(point, projected))
    return best


def validate_metadata(image_path: Path, metadata: dict, overlay: Path | None, expected: int):
    image = Image.open(image_path).convert("RGB")
    if list(image.size) != metadata.get("size"):
        raise ValueError(f"{image_path}: route size {metadata.get('size')} != image size {image.size}")
    stops = metadata.get("stops", [])
    keys = [stop.get("key") for stop in stops]
    required = ([f"unit{i}" for i in range(1, expected + 1)] if image_path.stem == "book"
                else ["t1", "t2", "t3", "t4", "all", "boss"])
    if keys != required:
        raise ValueError(f"{image_path}: expected stop keys {required}, got {keys}")
    path = metadata.get("path", [])
    if len(path) < 2:
        raise ValueError(f"{image_path}: path has fewer than two points")
    for a, b in zip(path, path[1:]):
        if math.dist(a, b) > 121:
            raise ValueError(f"{image_path}: path sample spacing exceeds 120 px")
    for stop in stops:
        point = (stop["x"], stop["y"])
        if not (0 <= point[0] < image.width and 0 <= point[1] < image.height):
            raise ValueError(f"{image_path}: stop out of bounds: {stop}")
        if distance_to_path(point, path) > 32:
            raise ValueError(f"{image_path}: stop is off path: {stop}")
    if overlay:
        draw = ImageDraw.Draw(image)
        draw.line([tuple(p) for p in path], fill="#ff3470", width=5, joint="curve")
        for stop in stops:
            x, y = stop["x"], stop["y"]
            draw.ellipse((x - 14, y - 14, x + 14, y + 14), fill="#ff3470", outline="white", width=3)
            draw.text((x + 16, y - 12), stop["key"], fill="white", stroke_width=2,
                      stroke_fill="#162438")
        image.save(overlay)
    return stops


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--overlay-dir", type=Path)
    parser.add_argument("--expected", type=int, default=6)
    parser.add_argument("--route-json", type=Path, help="Route metadata with size, stops and path")
    args = parser.parse_args()
    route = None
    metadata = None
    if args.route_json:
        points = json.loads(args.route_json.read_text(encoding="utf-8"))
        if isinstance(points, dict):
            metadata = points
        else:
            if len(points) < 2 or any(len(point) != 2 for point in points):
                parser.error("--route-json needs at least two [x,y] points")
            route = [tuple(map(int, point)) for point in points]
    if args.overlay_dir:
        args.overlay_dir.mkdir(parents=True, exist_ok=True)
    failed = False
    for path in args.images:
        overlay = args.overlay_dir / path.name if args.overlay_dir else None
        if metadata is not None:
            found = validate_metadata(path, metadata, overlay, args.expected)
        else:
            found = find_waypoints(path, overlay, route)
        status = "OK" if len(found) == args.expected else "FAIL"
        coords = [(stop["x"], stop["y"]) for stop in found] if metadata else [(x, y) for x, y, _ in found]
        print(f"{status} {path.name}: {len(found)} areas: {coords}")
        failed |= len(found) != args.expected
    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
