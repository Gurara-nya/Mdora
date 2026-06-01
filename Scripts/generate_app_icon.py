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


def rounded_line(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    width: int,
    fill: tuple[int, int, int, int],
) -> None:
    draw.line([start, end], width=width, fill=fill)
    radius = width // 2
    for point in (start, end):
        draw.ellipse(
            (
                point[0] - radius,
                point[1] - radius,
                point[0] + radius,
                point[1] + radius,
            ),
            fill=fill,
        )


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

    mark_shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    mark_shadow_draw = ImageDraw.Draw(mark_shadow, "RGBA")
    mark_width = s(56)
    for start, end in (
        ((s(424), s(428)), (s(375), s(725))),
        ((s(603), s(428)), (s(554), s(725))),
        ((s(347), s(531)), (s(690), s(531))),
        ((s(326), s(650)), (s(669), s(650))),
    ):
        rounded_line(mark_shadow_draw, start, end, mark_width, (44, 88, 151, 92))
    mark_shadow = mark_shadow.filter(ImageFilter.GaussianBlur(s(9)))
    image.alpha_composite(mark_shadow, (s(0), s(9)))

    mark = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    mark_draw = ImageDraw.Draw(mark, "RGBA")
    for start, end in (
        ((s(424), s(428)), (s(375), s(725))),
        ((s(603), s(428)), (s(554), s(725))),
        ((s(347), s(531)), (s(690), s(531))),
        ((s(326), s(650)), (s(669), s(650))),
    ):
        rounded_line(mark_draw, start, end, mark_width, (87, 151, 202, 146))
        rounded_line(mark_draw, (start[0] - s(4), start[1] - s(5)), (end[0] - s(4), end[1] - s(5)), s(18), (255, 255, 255, 106))
        rounded_line(mark_draw, (start[0] + s(5), start[1] + s(5)), (end[0] + s(5), end[1] + s(5)), s(12), (71, 116, 187, 68))
    image.alpha_composite(mark)

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
