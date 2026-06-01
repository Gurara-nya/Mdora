#!/usr/bin/env python3
from __future__ import annotations

import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Assets"
SOURCE = ASSETS / "AppIconSource.png"
ICONSET = ASSETS / "AppIcon.iconset"
ICNS = ASSETS / "AppIcon.icns"

SIZE = 1024
SCALE = 3
CANVAS = SIZE * SCALE


def s(value: float) -> int:
    return int(round(value * SCALE))


def lerp(a: int, b: int, t: float) -> int:
    return int(round(a + (b - a) * t))


def vertical_gradient(width: int, height: int, stops: list[tuple[float, tuple[int, int, int, int]]]) -> Image.Image:
    image = Image.new("RGBA", (width, height))
    draw = ImageDraw.Draw(image)

    for y in range(height):
        position = y / max(height - 1, 1)
        lower = stops[0]
        upper = stops[-1]

        for index in range(len(stops) - 1):
            if stops[index][0] <= position <= stops[index + 1][0]:
                lower = stops[index]
                upper = stops[index + 1]
                break

        span = max(upper[0] - lower[0], 0.0001)
        t = (position - lower[0]) / span
        color = tuple(lerp(lower[1][channel], upper[1][channel], t) for channel in range(4))
        draw.line([(0, y), (width, y)], fill=color)

    return image


def rounded_mask(size: tuple[int, int], radius: int, rect: tuple[int, int, int, int] | None = None) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    bounds = rect or (0, 0, size[0] - 1, size[1] - 1)
    draw.rounded_rectangle(bounds, radius=radius, fill=255)
    return mask


def paste_with_mask(base: Image.Image, layer: Image.Image, mask: Image.Image) -> None:
    masked = Image.new("RGBA", base.size, (0, 0, 0, 0))
    masked.paste(layer, (0, 0), mask)
    base.alpha_composite(masked)


def add_shadow(base: Image.Image, mask: Image.Image, color: tuple[int, int, int, int], offset: tuple[int, int], blur: int) -> None:
    shadow = Image.new("RGBA", base.size, color)
    alpha = mask.filter(ImageFilter.GaussianBlur(blur))
    shadow.putalpha(alpha.point(lambda value: int(value * color[3] / 255)))
    base.alpha_composite(shadow, offset)


def radial_glow(
    base: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int, int],
    steps: int = 96,
) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow, "RGBA")
    cx, cy = center

    for step in range(steps, 0, -1):
        t = step / steps
        alpha = int(color[3] * (1 - t) ** 1.8)
        current_radius = int(radius * t)
        draw.ellipse(
            (
                cx - current_radius,
                cy - current_radius,
                cx + current_radius,
                cy + current_radius,
            ),
            fill=(color[0], color[1], color[2], alpha),
        )

    base.alpha_composite(glow)


def cubic_points(
    start: tuple[int, int],
    control1: tuple[int, int],
    control2: tuple[int, int],
    end: tuple[int, int],
    steps: int,
) -> list[tuple[int, int]]:
    points: list[tuple[int, int]] = []

    for step in range(steps + 1):
        t = step / steps
        mt = 1 - t
        x = (
            mt ** 3 * start[0]
            + 3 * mt ** 2 * t * control1[0]
            + 3 * mt * t ** 2 * control2[0]
            + t ** 3 * end[0]
        )
        y = (
            mt ** 3 * start[1]
            + 3 * mt ** 2 * t * control1[1]
            + 3 * mt * t ** 2 * control2[1]
            + t ** 3 * end[1]
        )
        points.append((int(round(x)), int(round(y))))

    return points


def liquid_monogram_points() -> list[tuple[int, int]]:
    segments = [
        ((s(318), s(684)), (s(318), s(574)), (s(322), s(436)), (s(386), s(406))),
        ((s(386), s(406)), (s(445), s(378)), (s(478), s(539)), (s(512), s(616))),
        ((s(512), s(616)), (s(546), s(539)), (s(579), s(378)), (s(638), s(406))),
        ((s(638), s(406)), (s(702), s(436)), (s(706), s(574)), (s(706), s(684))),
    ]

    points: list[tuple[int, int]] = []
    for segment in segments:
        sampled = cubic_points(*segment, steps=56)
        if points:
            sampled = sampled[1:]
        points.extend(sampled)

    return points


def draw_round_path(mask: Image.Image, points: list[tuple[int, int]], width: int, fill: int = 255) -> None:
    draw = ImageDraw.Draw(mask)
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width // 2

    for point in points[::3] + points[-1:]:
        draw.ellipse(
            (
                point[0] - radius,
                point[1] - radius,
                point[0] + radius,
                point[1] + radius,
            ),
            fill=fill,
        )


def draw_round_rgba_path(
    layer: Image.Image,
    points: list[tuple[int, int]],
    width: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")
    draw.line(points, fill=fill, width=width, joint="curve")
    radius = width // 2

    for point in points[::3] + points[-1:]:
        draw.ellipse(
            (
                point[0] - radius,
                point[1] - radius,
                point[0] + radius,
                point[1] + radius,
            ),
            fill=fill,
        )


def draw_liquid_monogram(base: Image.Image) -> None:
    points = liquid_monogram_points()
    mask = Image.new("L", base.size, 0)
    draw_round_path(mask, points, s(78))

    shadow = Image.new("RGBA", base.size, (39, 90, 170, 80))
    shadow_alpha = mask.filter(ImageFilter.GaussianBlur(s(13)))
    shadow.putalpha(shadow_alpha)
    base.alpha_composite(shadow, (s(0), s(16)))

    soft_shadow = Image.new("RGBA", base.size, (93, 95, 220, 36))
    soft_shadow_alpha = mask.filter(ImageFilter.GaussianBlur(s(28)))
    soft_shadow.putalpha(soft_shadow_alpha)
    base.alpha_composite(soft_shadow, (s(0), s(28)))

    body = vertical_gradient(
        CANVAS,
        CANVAS,
        [
            (0.00, (222, 253, 255, 210)),
            (0.32, (126, 205, 241, 198)),
            (0.70, (93, 151, 222, 178)),
            (1.00, (154, 148, 248, 154)),
        ],
    )
    radial_glow(body, (s(376), s(432)), s(220), (255, 255, 255, 118), steps=52)
    radial_glow(body, (s(636), s(680)), s(270), (100, 218, 255, 64), steps=52)
    paste_with_mask(base, body, mask)

    glass = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_round_rgba_path(glass, points, s(80), (255, 255, 255, 46))
    draw_round_rgba_path(glass, points, s(70), (80, 157, 222, 88))
    draw_round_rgba_path(glass, [(x - s(12), y - s(15)) for x, y in points], s(15), (255, 255, 255, 164))
    draw_round_rgba_path(glass, [(x - s(2), y + s(2)) for x, y in points], s(9), (223, 250, 255, 58))
    draw_round_rgba_path(glass, [(x + s(10), y + s(12)) for x, y in points], s(13), (49, 95, 188, 54))
    glass.putalpha(Image.composite(glass.getchannel("A"), Image.new("L", base.size, 0), mask))
    base.alpha_composite(glass)

    sparkle = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle, "RGBA")
    sparkle_draw.ellipse((s(366), s(400), s(418), s(452)), fill=(255, 255, 255, 66))
    sparkle_draw.ellipse((s(618), s(400), s(662), s(444)), fill=(255, 255, 255, 50))
    sparkle_draw.ellipse((s(488), s(588), s(532), s(632)), fill=(255, 255, 255, 30))
    sparkle.putalpha(Image.composite(sparkle.getchannel("A").filter(ImageFilter.GaussianBlur(s(9))), Image.new("L", base.size, 0), mask))
    base.alpha_composite(sparkle)


def create_icon() -> Image.Image:
    image = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))

    base_mask = rounded_mask((CANVAS, CANVAS), s(226))
    base_gradient = vertical_gradient(
        CANVAS,
        CANVAS,
        [
            (0.00, (138, 235, 244, 255)),
            (0.34, (158, 242, 229, 255)),
            (0.61, (142, 195, 255, 255)),
            (1.00, (127, 102, 248, 255)),
        ],
    )
    radial_glow(base_gradient, (s(210), s(240)), s(520), (255, 255, 255, 92))
    radial_glow(base_gradient, (s(790), s(190)), s(430), (70, 203, 255, 72))
    radial_glow(base_gradient, (s(230), s(805)), s(520), (255, 132, 218, 86))
    paste_with_mask(image, base_gradient, base_mask)

    rim = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim, "RGBA")
    rim_draw.rounded_rectangle((s(4), s(4), s(1020), s(1020)), radius=s(224), outline=(255, 255, 255, 156), width=s(18))
    rim_draw.rounded_rectangle((s(25), s(26), s(999), s(1001)), radius=s(207), outline=(255, 255, 255, 60), width=s(8))
    rim_draw.rounded_rectangle((s(38), s(40), s(986), s(986)), radius=s(195), outline=(37, 96, 222, 44), width=s(8))
    image.alpha_composite(rim)

    paper_rect = (s(170), s(150), s(868), s(874))
    paper_radius = s(82)
    paper_mask = rounded_mask((CANVAS, CANVAS), paper_radius, paper_rect)
    add_shadow(image, paper_mask, (28, 65, 160, 104), (s(0), s(34)), s(30))
    add_shadow(image, paper_mask, (91, 69, 218, 46), (s(0), s(11)), s(8))

    paper = vertical_gradient(
        CANVAS,
        CANVAS,
        [
            (0.00, (248, 255, 255, 232)),
            (0.42, (226, 251, 255, 218)),
            (0.78, (220, 226, 255, 226)),
            (1.00, (194, 211, 255, 238)),
        ],
    )
    radial_glow(paper, (s(214), s(220)), s(330), (255, 255, 255, 148))
    radial_glow(paper, (s(768), s(708)), s(410), (103, 168, 255, 82))
    paste_with_mask(image, paper, paper_mask)

    paper_edge = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    edge_draw = ImageDraw.Draw(paper_edge, "RGBA")
    edge_draw.rounded_rectangle(paper_rect, radius=paper_radius, outline=(255, 255, 255, 205), width=s(9))
    edge_draw.rounded_rectangle((s(171), s(154), s(864), s(864)), radius=s(72), outline=(255, 255, 255, 78), width=s(7))
    image.alpha_composite(paper_edge)

    fold = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    fold_draw = ImageDraw.Draw(fold, "RGBA")
    fold_points = [(s(668), s(150)), (s(868), s(350)), (s(868), s(190)), (s(826), s(150))]
    fold_draw.polygon(fold_points, fill=(180, 238, 255, 172))
    fold_draw.line([(s(668), s(150)), (s(868), s(350))], fill=(255, 255, 255, 215), width=s(8))
    fold_draw.line([(s(702), s(184)), (s(846), s(328))], fill=(114, 196, 255, 105), width=s(9))
    fold_draw.line([(s(742), s(162)), (s(860), s(280))], fill=(255, 255, 255, 118), width=s(6))
    fold.putalpha(fold.getchannel("A").filter(ImageFilter.GaussianBlur(s(0.4))))
    image.alpha_composite(fold)

    draw_liquid_monogram(image)

    return image.resize((SIZE, SIZE), Image.Resampling.LANCZOS)


def write_iconset(source: Image.Image) -> None:
    ICONSET.mkdir(parents=True, exist_ok=True)
    targets = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }

    for name, size in targets.items():
        source.resize((size, size), Image.Resampling.LANCZOS).save(ICONSET / name)


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    icon = create_icon()
    icon.save(SOURCE)
    write_iconset(icon)
    subprocess.run(["iconutil", "-c", "icns", "-o", str(ICNS), str(ICONSET)], check=True)
    print(f"wrote {SOURCE}")
    print(f"wrote {ICNS}")


if __name__ == "__main__":
    main()
