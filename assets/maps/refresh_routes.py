"""Build pixel route metadata for the current Monster Slam map images.

Run before resizing source PNGs to 1920 x 1080 WebP. The saved routes refer to
the WebP image dimensions used by the game.
"""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
TARGET_SIZE = (1920, 1080)
UNIT_KEYS = ("t1", "t2", "t3", "t4", "all", "boss")

NEW_UNIT_PATHS = {
    5: [[1480, 100], [1360, 145], [1220, 170], [1100, 190], [980, 210],
        [870, 260], [780, 265], [680, 285], [575, 350], [470, 420],
        [575, 470], [650, 530], [755, 590], [630, 645], [480, 690],
        [350, 700], [255, 655]],
    6: [[170, 100], [320, 155], [465, 215], [535, 275], [600, 340],
        [760, 390], [880, 450], [990, 470], [1020, 555], [1030, 640],
        [1150, 615], [1240, 550], [1300, 470], [1320, 370],
        [1320, 290], [1370, 220], [1450, 125]],
}
NEW_UNIT_STOPS = {
    5: [[1480, 100], [1100, 190], [680, 285], [575, 470], [755, 590], [255, 655]],
    6: [[170, 100], [465, 215], [600, 340], [990, 470], [1030, 640], [1450, 125]],
}

CORRECTED_UNIT_PATHS = {
    (3, 3): [[1252, 722], [1190, 670], [1072, 572], [920, 550],
             [800, 500], [712, 444], [850, 440], [920, 405],
             [990, 380], [1050, 345], [1109, 312], [970, 275],
             [850, 235], [746, 188], [600, 165], [450, 140], [246, 134]],
    (4, 1): [[177, 220], [330, 185], [557, 162], [650, 210],
             [740, 260], [815, 320], [886, 364], [810, 435],
             [680, 505], [527, 574], [650, 600], [850, 600],
             [1122, 600], [1210, 525], [1250, 430], [1300, 325],
             [1420, 168]],
    (4, 4): [[174, 768], [400, 670], [655, 524], [900, 520],
             [1112, 534], [1160, 430], [1160, 330], [1040, 285],
             [900, 220], [790, 175], [697, 200], [840, 145],
             [1000, 130], [1150, 145], [1300, 170], [1421, 148]],
}

# Anchors follow the visible pale road in each overview, in unit order.
BOOK_ROUTES = {
    2: {
        "stops": [[1010, 645], [475, 520], [730, 315], [1290, 130], [980, 120], [770, 85]],
        "path": [[1010, 645], [900, 635], [780, 600], [650, 560], [560, 525],
                 [475, 520], [575, 485], [675, 435], [715, 375], [730, 315],
                 [845, 310], [960, 285], [1055, 250], [1160, 220], [1240, 175],
                 [1290, 130], [1180, 142], [1080, 143], [980, 120], [870, 110], [770, 85]],
    },
    3: {
        "stops": [[525, 460], [790, 180], [1180, 330], [1205, 530]],
        "path": [[525, 460], [590, 430], [650, 380], [680, 320], [730, 275],
                 [745, 225], [790, 180], [900, 220], [1010, 245], [1100, 285],
                 [1180, 330], [1200, 415], [1250, 480], [1205, 530]],
    },
    4: {
        "stops": [[700, 210], [950, 345], [490, 460], [710, 745]],
        "path": [[700, 210], [720, 265], [755, 300], [830, 320], [950, 345],
                 [890, 400], [780, 425], [690, 400], [600, 430], [490, 460],
                 [530, 500], [580, 545], [590, 610], [650, 675], [710, 745]],
    },
}


def scaled(point, old_size):
    if old_size == (1536, 1024):
        # Crop 80 sky/sea pixels at each edge before resizing to 16:9.
        return [round(point[0] * 1.25), round((point[1] - 80) * 1.25)]
    return [round(point[0] * TARGET_SIZE[0] / old_size[0]),
            round(point[1] * TARGET_SIZE[1] / old_size[1])]


def dense(points, spacing=100):
    result = [points[0]]
    for a, b in zip(points, points[1:]):
        steps = max(1, math.ceil(math.dist(a, b) / spacing))
        for step in range(1, steps + 1):
            t = step / steps
            candidate = [round(a[0] + (b[0] - a[0]) * t),
                         round(a[1] + (b[1] - a[1]) * t)]
            if candidate != result[-1]:
                result.append(candidate)
    return result


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def unit_routes(access, mapping):
    folder = ROOT / f"access{access}"
    for unit in range(1, 7 if access == 2 else 5):
        image_size = Image.open(folder / f"unit{unit}.png").size
        route_file = folder / f"unit{unit}-route.json"
        if (access, unit) in CORRECTED_UNIT_PATHS:
            anchors = CORRECTED_UNIT_PATHS[(access, unit)]
            source_stops = [[mapping["areas"][str(unit)][key]["x"] * image_size[0],
                             mapping["areas"][str(unit)][key]["y"] * image_size[1]]
                            for key in UNIT_KEYS]
        elif access == 2 and unit in NEW_UNIT_PATHS:
            anchors = NEW_UNIT_PATHS[unit]
            source_stops = NEW_UNIT_STOPS[unit]
        else:
            previous = json.loads(route_file.read_text(encoding="utf-8"))
            if isinstance(previous, list):
                anchors = previous
            else:
                anchors = [[point[0] * image_size[0] / previous["size"][0],
                            point[1] * image_size[1] / previous["size"][1]]
                           for point in previous["path"]]
            source_stops = [[mapping["areas"][str(unit)][key]["x"] * image_size[0],
                             mapping["areas"][str(unit)][key]["y"] * image_size[1]]
                            for key in UNIT_KEYS]
            if access == 3 and unit == 1 and isinstance(previous, list):
                # Follow the bend at the top of the stair before t3.
                anchors.insert(3, [760, 190])
                anchors.insert(5, [870, 345])

        anchors = [scaled(point, image_size) for point in anchors]
        stops = [scaled(point, image_size) for point in source_stops]
        # Existing anchors are already near stop centers. Snap the closest
        # ordered vertex to each explicit stop to keep path and stops aligned.
        first = 0
        for stop in stops:
            best = min(range(first, len(anchors)), key=lambda i: math.dist(anchors[i], stop))
            if math.dist(anchors[best], stop) > 60:
                raise ValueError(f"access{access} unit{unit}: stop too far from route: {stop}")
            anchors[best] = stop
            first = best + 1
        route = {"size": list(TARGET_SIZE),
                 "stops": [{"key": key, "x": point[0], "y": point[1]}
                           for key, point in zip(UNIT_KEYS, stops)],
                 "path": dense(anchors)}
        save(route_file, route)
        if access == 2 and unit in NEW_UNIT_PATHS:
            mapping["areas"][str(unit)] = {
                **{key: {"x": round(point[0] / image_size[0], 4),
                         "y": round(point[1] / image_size[1], 4)}
                   for key, point in zip(UNIT_KEYS, source_stops)},
                "path": [{"x": round(point[0] / image_size[0], 4),
                          "y": round(point[1] / image_size[1], 4)}
                         for point in NEW_UNIT_PATHS[unit]],
            }


def book_route(access, mapping):
    folder = ROOT / f"access{access}"
    old_size = Image.open(folder / "book.png").size
    route = BOOK_ROUTES[access]
    stop_points = [scaled(point, old_size) for point in route["stops"]]
    path_points = dense([scaled(point, old_size) for point in route["path"]])
    save(folder / "book-route.json", {
        "size": list(TARGET_SIZE),
        "stops": [{"key": f"unit{i}", "x": x, "y": y}
                  for i, (x, y) in enumerate(stop_points, 1)],
        "path": path_points,
    })
    mapping["units"] = {
        **{str(i): {"x": round(point[0] / TARGET_SIZE[0], 4),
                     "y": round(point[1] / TARGET_SIZE[1], 4)}
           for i, point in enumerate(stop_points, 1)},
        "path": [{"x": round(point[0] / TARGET_SIZE[0], 4),
                  "y": round(point[1] / TARGET_SIZE[1], 4)}
                 for point in path_points],
    }


def main():
    for access in (2, 3, 4):
        folder = ROOT / f"access{access}"
        map_file = folder / "map.json"
        mapping = json.loads(map_file.read_text(encoding="utf-8"))
        unit_routes(access, mapping)
        book_route(access, mapping)
        map_file.write_text(json.dumps(mapping, ensure_ascii=False, indent="\t") + "\n",
                            encoding="utf-8")


if __name__ == "__main__":
    main()
