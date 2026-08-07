# ABOUTME: Builds the 1200x627 LinkedIn card from repo artwork plus a real headshot.
# ABOUTME: The photo is composited, never regenerated, so the likeness stays exact.

# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow>=10"]
# ///
"""Build the LinkedIn share card for this workshop.

The headshot is deliberately not committed. Pass a path to one:

    uv run scripts/build-linkedin-hero.py ~/path/to/headshot.jpg
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
ASSETS = REPO / "assets"
W, H = 1200, 627  # LinkedIn link-preview / featured card

FONT_BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
FONT_SEMI = "/usr/share/fonts/truetype/noto/NotoSans-SemiBold.ttf"
FONT_REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"

TEAL = (56, 214, 205)
AMBER = (240, 168, 76)
WHITE = (255, 255, 255)
MUTED = (176, 192, 208)


def cover_crop(im: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to fill w x h, centre-cropping the overflow."""
    scale = max(w / im.width, h / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
    left = (im.width - w) // 2
    top = (im.height - h) // 2
    return im.crop((left, top, left + w, top + h))


def portrait_crop(im: Image.Image, zoom: float = 0.62, eye_line: float = 0.42) -> Image.Image:
    """Crop a square around the subject's head.

    A plain centre-crop of a typical headshot keeps ceiling and shoulders, which
    leaves the face tiny once it is scaled into a small circle. Take a square a
    fraction of the short edge, centred horizontally and biased up the frame.

    Args:
        im: Source photo.
        zoom: Side of the crop square as a fraction of the shorter edge.
        eye_line: Vertical centre of the crop as a fraction of image height.

    Returns:
        The cropped square, clamped to stay inside the source.
    """
    side = round(min(im.width, im.height) * zoom)
    cx = im.width // 2
    cy = round(im.height * eye_line)
    left = max(0, min(cx - side // 2, im.width - side))
    top = max(0, min(cy - side // 2, im.height - side))
    return im.crop((left, top, left + side, top + side))


def circular(im: Image.Image, size: int, ring: int = 6, ring_color=TEAL) -> Image.Image:
    """Circle-crop a photo and draw a ring around it, at 4x for clean edges."""
    ss = 4
    inner = size - ring * 2
    photo = cover_crop(portrait_crop(im), inner * ss, inner * ss)

    mask = Image.new("L", (inner * ss, inner * ss), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, inner * ss - 1, inner * ss - 1), fill=255)

    out = Image.new("RGBA", (size * ss, size * ss), (0, 0, 0, 0))
    ImageDraw.Draw(out).ellipse((0, 0, size * ss - 1, size * ss - 1), fill=ring_color + (255,))
    out.paste(photo, (ring * ss, ring * ss), mask)
    return out.resize((size, size), Image.LANCZOS)


def scrim(base: Image.Image, box, opacity_left=225, opacity_right=0) -> None:
    """Horizontal dark gradient so text stays legible over artwork."""
    x0, y0, x1, y1 = box
    grad = Image.new("L", (x1 - x0, 1))
    for x in range(x1 - x0):
        t = x / max(1, (x1 - x0) - 1)
        grad.putpixel((x, 0), round(opacity_left + (opacity_right - opacity_left) * t))
    alpha = grad.resize((x1 - x0, y1 - y0))
    panel = Image.new("RGBA", (x1 - x0, y1 - y0), (7, 14, 26, 255))
    panel.putalpha(alpha)
    base.alpha_composite(panel, (x0, y0))


def build(art_path: Path, head_path: Path, out_path: Path, scrim_strength: int = 225) -> None:
    base = cover_crop(Image.open(art_path).convert("RGBA"), W, H)

    # Push the illustration back slightly so foreground type reads first.
    base = Image.blend(base, base.filter(ImageFilter.GaussianBlur(1.2)), 0.35)
    # Bright artwork needs a stronger, wider scrim or the byline sits on white.
    width = 0.74 if scrim_strength <= 225 else 0.86
    scrim(base, (0, 0, int(W * width), H), opacity_left=scrim_strength)

    d = ImageDraw.Draw(base)
    x = 64

    f_kicker = ImageFont.truetype(FONT_SEMI, 22)
    f_title = ImageFont.truetype(FONT_BOLD, 62)
    f_sub = ImageFont.truetype(FONT_REG, 25)
    f_score = ImageFont.truetype(FONT_BOLD, 31)
    f_lab = ImageFont.truetype(FONT_SEMI, 17)
    f_name = ImageFont.truetype(FONT_BOLD, 27)
    f_role = ImageFont.truetype(FONT_REG, 19)

    d.text((x, 74), "KCD TEXAS 2026  ·  LIVE WORKSHOP", font=f_kicker, fill=TEAL)
    d.text((x, 112), "The 90-Minute IDP", font=f_title, fill=WHITE)
    d.text((x, 192), "27 CNCF components built live with AI,", font=f_sub, fill=MUTED)
    d.text((x, 224), "then scored on what it actually left behind.", font=f_sub, fill=MUTED)

    # The finding: three numbers and the gap between them.
    d.line((x, 286, x + 470, 286), fill=(48, 66, 88), width=2)
    for i, (val, lab, col) in enumerate(
        [("9.7", "INSTALL", TEAL), ("8.1", "INTEGRATION", WHITE), ("7.1", "USABILITY", AMBER)]
    ):
        cx = x + i * 165
        d.text((cx, 308), val, font=f_score, fill=col)
        d.text((cx, 348), lab, font=f_lab, fill=MUTED)

    # Real photo, composited rather than generated.
    head = circular(Image.open(head_path).convert("RGB"), 132)
    hy = H - 132 - 62

    # Soft plate under the identity block: the byline otherwise runs onto
    # whatever the artwork puts there, and light artwork wins that contest.
    plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(plate).rounded_rectangle(
        (x - 18, hy - 16, x + 620, hy + 148), radius=84, fill=(7, 14, 26, 200)
    )
    base.alpha_composite(plate.filter(ImageFilter.GaussianBlur(10)))

    base.alpha_composite(head, (x, hy))
    d.text((x + 152, hy + 34), "Michael Forrester", font=f_name, fill=WHITE)
    d.text((x + 152, hy + 70), "Platform engineering · Developer education", font=f_role, fill=MUTED)

    base.convert("RGB").save(out_path, quality=95)
    print(f"wrote {out_path} ({W}x{H})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("headshot", type=Path, help="path to a headshot image")
    args = parser.parse_args()

    if not args.headshot.is_file():
        print(f"headshot not found: {args.headshot}", file=sys.stderr)
        return 1

    # The clown banner is bright, so it needs a heavier scrim than the hero art.
    build(ASSETS / "hero.png", args.headshot, ASSETS / "linkedin-hero.png")
    build(
        ASSETS / "clown-native-banner.png",
        args.headshot,
        ASSETS / "linkedin-hero-clown.png",
        scrim_strength=246,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
