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


def liquid_flow_points() -> list[tuple[int, int]]:
    segments = [
        ((s(290), s(632)), (s(294), s(528)), (s(340), s(448)), (s(438), s(424))),
        ((s(438), s(424)), (s(532), s(401)), (s(588), s(501)), (s(538), s(578))),
        ((s(538), s(578)), (s(502), s(634)), (s(455), s(702)), (s(530), s(724))),
        ((s(530), s(724)), (s(624), s(752)), (s(610), s(592)), (s(664), s(502))),
        ((s(664), s(502)), (s(710), s(426)), (s(790), s(428)), (s(798), s(520))),
        ((s(798), s(520)), (s(807), s(618)), (s(744), s(664)), (s(670), s(670))),
    ]

    points: list[tuple[int, int]] = []
    for segment in segments:
        sampled = cubic_points(*segment, steps=56)
        if points:
            sampled = sampled[1:]
        points.extend(sampled)

    return points


def path_width_at(index: int, point_count: int, base_width: int) -> int:
    if point_count <= 1:
        return base_width

    t = index / (point_count - 1)
    end_taper = min(1.0, min(t, 1 - t) * 4.2)
    waist = 0.94 + 0.08 * (1 - abs(0.5 - t) * 2)
    return int(round(base_width * (0.64 + 0.36 * end_taper) * waist))


def draw_variable_round_path(mask: Image.Image, points: list[tuple[int, int]], width: int, fill: int = 255) -> None:
    draw = ImageDraw.Draw(mask)

    for index in range(len(points) - 1):
        current_width = max(1, path_width_at(index, len(points), width))
        draw.line((points[index], points[index + 1]), fill=fill, width=current_width, joint="curve")

    for index, point in enumerate(points):
        radius = max(1, path_width_at(index, len(points), width) // 2)
        draw.ellipse(
            (
                point[0] - radius,
                point[1] - radius,
                point[0] + radius,
                point[1] + radius,
            ),
            fill=fill,
        )


def draw_variable_rgba_path(
    layer: Image.Image,
    points: list[tuple[int, int]],
    width: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw = ImageDraw.Draw(layer, "RGBA")

    for index in range(len(points) - 1):
        current_width = max(1, path_width_at(index, len(points), width))
        draw.line((points[index], points[index + 1]), fill=fill, width=current_width, joint="curve")

    for index, point in enumerate(points):
        radius = max(1, path_width_at(index, len(points), width) // 2)
        draw.ellipse(
            (
                point[0] - radius,
                point[1] - radius,
                point[0] + radius,
                point[1] + radius,
            ),
            fill=fill,
        )


def shifted_points(points: list[tuple[int, int]], dx: int, dy: int) -> list[tuple[int, int]]:
    return [(x + dx, y + dy) for x, y in points]


def draw_liquid_flow_mark(base: Image.Image) -> None:
    points = liquid_flow_points()
    mask = Image.new("L", base.size, 0)
    draw_variable_round_path(mask, points, s(92))

    shadow = Image.new("RGBA", base.size, (33, 82, 180, 74))
    shadow_alpha = mask.filter(ImageFilter.GaussianBlur(s(16)))
    shadow.putalpha(shadow_alpha)
    base.alpha_composite(shadow, (s(0), s(18)))

    soft_shadow = Image.new("RGBA", base.size, (92, 82, 226, 34))
    soft_shadow_alpha = mask.filter(ImageFilter.GaussianBlur(s(36)))
    soft_shadow.putalpha(soft_shadow_alpha)
    base.alpha_composite(soft_shadow, (s(0), s(31)))

    body = vertical_gradient(
        CANVAS,
        CANVAS,
        [
            (0.00, (244, 255, 255, 202)),
            (0.28, (163, 230, 255, 188)),
            (0.62, (92, 167, 232, 174)),
            (1.00, (154, 143, 248, 152)),
        ],
    )
    radial_glow(body, (s(370), s(438)), s(220), (255, 255, 255, 136), steps=56)
    radial_glow(body, (s(575), s(690)), s(260), (129, 104, 255, 72), steps=56)
    radial_glow(body, (s(776), s(488)), s(210), (93, 230, 255, 78), steps=56)
    paste_with_mask(base, body, mask)

    glass = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_variable_rgba_path(glass, points, s(104), (255, 255, 255, 48))
    draw_variable_rgba_path(glass, points, s(90), (66, 154, 226, 82))
    draw_variable_rgba_path(glass, shifted_points(points, -s(15), -s(16)), s(17), (255, 255, 255, 188))
    draw_variable_rgba_path(glass, shifted_points(points, -s(3), -s(3)), s(8), (230, 252, 255, 64))
    draw_variable_rgba_path(glass, shifted_points(points, s(12), s(14)), s(16), (50, 94, 190, 50))
    glass.putalpha(Image.composite(glass.getchannel("A"), Image.new("L", base.size, 0), mask))
    base.alpha_composite(glass)

    edge = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_variable_rgba_path(edge, points, s(100), (255, 255, 255, 42))
    draw_variable_rgba_path(edge, shifted_points(points, s(7), s(8)), s(82), (64, 119, 218, 36))
    edge_alpha = Image.composite(edge.getchannel("A").filter(ImageFilter.GaussianBlur(s(1.2))), Image.new("L", base.size, 0), mask)
    edge.putalpha(edge_alpha)
    base.alpha_composite(edge)

    sparkle = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sparkle_draw = ImageDraw.Draw(sparkle, "RGBA")
    sparkle_draw.ellipse((s(388), s(396), s(452), s(452)), fill=(255, 255, 255, 72))
    sparkle_draw.ellipse((s(517), s(560), s(562), s(607)), fill=(255, 255, 255, 42))
    sparkle_draw.ellipse((s(742), s(438), s(789), s(482)), fill=(255, 255, 255, 54))
    sparkle.putalpha(Image.composite(sparkle.getchannel("A").filter(ImageFilter.GaussianBlur(s(8))), Image.new("L", base.size, 0), mask))
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

    draw_liquid_flow_mark(image)

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
