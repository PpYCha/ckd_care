from __future__ import annotations

from pathlib import Path
import math

import imageio.v2 as imageio
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_LOGO = Path(
    r"C:\Users\diasa\.codex\generated_images\01a074aa-3356-71c3-a32e-da00267fb768\call_mCAA06ZqnRGkpceah0kMeHRP.png"
)
BRAND_DIR = ROOT / "assets" / "branding"
STORE_DIR = ROOT / "store_assets"
PHONE_DIR = STORE_DIR / "phone"
TABLET7_DIR = STORE_DIR / "tablet_7_inch"
TABLET10_DIR = STORE_DIR / "tablet_10_inch"
CHROMEBOOK_DIR = STORE_DIR / "chromebook"
XR_DIR = STORE_DIR / "android_xr"

TEAL = "#1ebfb4"
BLUE = "#278bd3"
NAVY = "#17324d"
MINT = "#dff7f3"
AMBER = "#f5ad32"
BG = "#f7fbfd"
INK = "#183247"
SOFT = "#6b7f91"
CARD = "#ffffff"
LINE = "#d9e8ee"


def ensure_dirs() -> None:
    for folder in [
        BRAND_DIR,
        STORE_DIR,
        PHONE_DIR,
        TABLET7_DIR,
        TABLET10_DIR,
        CHROMEBOOK_DIR,
        XR_DIR,
    ]:
        folder.mkdir(parents=True, exist_ok=True)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        ROOT / "assets" / "fonts" / "Nunito.ttf",
        Path(r"C:\Windows\Fonts\segoeuib.ttf" if bold else r"C:\Windows\Fonts\segoeui.ttf"),
        Path(r"C:\Windows\Fonts\arialbd.ttf" if bold else r"C:\Windows\Fonts\arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def rounded_rect(draw: ImageDraw.ImageDraw, xy, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=radius, fill=fill, outline=outline, width=width)


def crop_logo_square(src: Image.Image) -> Image.Image:
    src = src.convert("RGBA")
    pix = src.load()
    w, h = src.size
    # The generated logo has a near-white background. Convert it to transparent
    # so Android adaptive masks and Play assets sit cleanly on brand color.
    for y in range(h):
        for x in range(w):
            r, g, b, a = pix[x, y]
            if r > 245 and g > 245 and b > 245:
                pix[x, y] = (255, 255, 255, 0)
    alpha = src.getchannel("A")
    bbox = alpha.getbbox()
    if not bbox:
        return src
    cropped = src.crop(bbox)
    pad = int(max(cropped.size) * 0.10)
    size = max(cropped.size) + pad * 2
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.alpha_composite(cropped, ((size - cropped.width) // 2, (size - cropped.height) // 2))
    return out


def make_icon(master: Image.Image, size: int, bg: str | None = None) -> Image.Image:
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(out)
    if bg:
        draw.rounded_rectangle((0, 0, size, size), radius=int(size * 0.22), fill=bg)
    mark_size = int(size * 0.82)
    mark = master.resize((mark_size, mark_size), Image.Resampling.LANCZOS)
    out.alpha_composite(mark, ((size - mark_size) // 2, (size - mark_size) // 2))
    return out


def save_launcher_icons(master: Image.Image) -> None:
    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in sizes.items():
        path = ROOT / "android" / "app" / "src" / "main" / "res" / folder / "ic_launcher.png"
        make_icon(master, size, bg="#f7fbfd").save(path)

    web_icons = {
        "Icon-192.png": (192, "#f7fbfd"),
        "Icon-512.png": (512, "#f7fbfd"),
        "Icon-maskable-192.png": (192, "#e9fbf7"),
        "Icon-maskable-512.png": (512, "#e9fbf7"),
    }
    for name, (size, bg) in web_icons.items():
        make_icon(master, size, bg=bg).save(ROOT / "web" / "icons" / name)

    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    ios_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in ios_sizes.items():
        make_icon(master, size, bg="#f7fbfd").convert("RGB").save(ios_dir / name)

    mac_sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    mac_dir = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for name, size in mac_sizes.items():
        make_icon(master, size, bg="#f7fbfd").convert("RGB").save(mac_dir / name)

    ico = make_icon(master, 256, bg="#f7fbfd").convert("RGBA")
    ico.save(ROOT / "windows" / "runner" / "resources" / "app_icon.ico", sizes=[(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)])


def text(draw, xy, value, size, fill=INK, bold=False, anchor=None, align="left"):
    draw.text(xy, value, font=font(size, bold), fill=fill, anchor=anchor, align=align)


def center_text(draw, box, value, size, fill=INK, bold=False):
    f = font(size, bold)
    bbox = draw.multiline_textbbox((0, 0), value, font=f, spacing=8, align="center")
    x = box[0] + (box[2] - box[0] - (bbox[2] - bbox[0])) / 2
    y = box[1] + (box[3] - box[1] - (bbox[3] - bbox[1])) / 2
    draw.multiline_text((x, y), value, font=f, fill=fill, spacing=8, align="center")


def wrap_text(draw, value: str, max_width: int, size: int, bold: bool = False) -> str:
    f = font(size, bold)
    words = value.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), trial, font=f)[2] <= max_width:
            current = trial
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def draw_phone_shell(img: Image.Image, xy, scale=1.0):
    draw = ImageDraw.Draw(img)
    x, y = xy
    w, h = int(360 * scale), int(720 * scale)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x + 18, y + 22, x + w + 18, y + h + 22), 42, fill=(36, 68, 90, 35))
    shadow = shadow.filter(ImageFilter.GaussianBlur(20))
    img.alpha_composite(shadow)
    rounded_rect(draw, (x, y, x + w, y + h), int(38 * scale), fill="#eff6f8", outline="#b9d2dc", width=3)
    rounded_rect(draw, (x + 14, y + 16, x + w - 14, y + h - 16), int(28 * scale), fill=BG)
    return (x + 14, y + 16, x + w - 14, y + h - 16)


def draw_mock_screen(draw, box, title, accent, rows):
    x1, y1, x2, y2 = box
    draw.rounded_rectangle(box, radius=28, fill=BG)
    text(draw, (x1 + 24, y1 + 28), title, 24, NAVY, True)
    draw.rounded_rectangle((x1 + 24, y1 + 78, x2 - 24, y1 + 210), 24, fill=accent)
    text(draw, (x1 + 48, y1 + 106), rows[0][0], 22, "white", True)
    text(draw, (x1 + 48, y1 + 146), rows[0][1], 17, "#eaffff")
    top = y1 + 240
    for i, (head, sub) in enumerate(rows[1:]):
        y = top + i * 98
        draw.rounded_rectangle((x1 + 24, y, x2 - 24, y + 76), 18, fill=CARD, outline=LINE, width=2)
        draw.ellipse((x1 + 42, y + 18, x1 + 82, y + 58), fill=MINT)
        text(draw, (x1 + 98, y + 16), head, 18, INK, True)
        text(draw, (x1 + 98, y + 42), sub, 14, SOFT)


def feature_graphic(master: Image.Image):
    img = Image.new("RGBA", (1024, 500), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, 1024, 500), fill="#f4fbfd")
    draw.ellipse((-150, -250, 520, 420), fill="#d8f6f1")
    draw.ellipse((680, 260, 1150, 650), fill="#d9edf9")
    text(draw, (70, 110), "KidneyTrack", 62, NAVY, True)
    text(draw, (73, 188), "Daily kidney care, organized", 31, "#31576f")
    text(draw, (75, 255), "Fluids  |  Medicines  |  Food guidance  |  Dialysis", 24, "#44687e")
    icon = make_icon(master, 236, bg="#ffffff")
    img.alpha_composite(icon, (708, 118))
    for i, (label, color) in enumerate(
        [("Fluid", TEAL), ("Medicine", AMBER), ("Dialysis", "#7b5fd0")]
    ):
        x = 708 + i * 88
        draw.rounded_rectangle((x, 378, x + 72, 420), 18, fill=color)
        text(draw, (x + 36, 388), label, 13, "white", True, anchor="ma")
    img.convert("RGB").save(STORE_DIR / "feature_graphic_1024x500.png", quality=95)


def screenshot(path: Path, headline: str, sub: str, screen_title: str, accent: str, rows, size=(1080, 1920)):
    img = Image.new("RGBA", size, BG)
    draw = ImageDraw.Draw(img)
    w, h = size
    draw.rectangle((0, 0, w, h), fill="#f5fbfd")
    draw.ellipse((-180, -220, 540, 500), fill="#d7f6ef")
    draw.ellipse((w - 520, h - 520, w + 220, h + 160), fill="#d8edf9")
    text(draw, (80, 100), "KidneyTrack", 48, NAVY, True)
    headline_size = 54 if len(headline) > 28 else 62
    wrapped_headline = wrap_text(draw, headline, w - 160, headline_size, True)
    text(draw, (80, 178), wrapped_headline, headline_size, INK, True)
    sub_y = 330 + 58 * (wrapped_headline.count("\n"))
    wrapped_sub = wrap_text(draw, sub, w - 164, 31)
    text(draw, (82, sub_y), wrapped_sub, 31, "#42647a")
    shell = draw_phone_shell(img, ((w - 430) // 2, 575), 1.12)
    draw_mock_screen(draw, shell, screen_title, accent, rows)
    img.convert("RGB").save(path, quality=95)


def wide_screenshot(path: Path, headline: str, sub: str, screen_title: str, accent: str, rows, size=(1920, 1080)):
    img = Image.new("RGBA", size, BG)
    draw = ImageDraw.Draw(img)
    w, h = size
    draw.rectangle((0, 0, w, h), fill="#f4fbfd")
    draw.ellipse((-260, -360, 780, 640), fill="#d7f6ef")
    draw.ellipse((1350, 610, 2220, 1280), fill="#d8edf9")
    text(draw, (120, 126), "KidneyTrack", 62, NAVY, True)
    text(draw, (120, 230), headline, 82, INK, True)
    text(draw, (124, 430), sub, 36, "#42647a")
    shell = draw_phone_shell(img, (1250, 94), 1.18)
    draw_mock_screen(draw, shell, screen_title, accent, rows)
    img.convert("RGB").save(path, quality=95)


SCREENS = [
    ("01_dashboard.png", "See today's care at a glance", "Track fluids, medicines, and dialysis timing from one calm dashboard.", "Today", TEAL, [
        ("Fluid progress", "650 of 1000 mL"),
        ("Next dialysis", "Monday, 7:00 AM"),
        ("Medicines", "Morning and evening"),
        ("Daily notes", "Small choices, steady care"),
    ]),
    ("02_fluid.png", "Stay within your fluid limit", "Log intake and output, then compare progress against your daily goal.", "Fluid", BLUE, [
        ("Today's intake", "650 of 1000 mL goal"),
        ("Add intake", "Water, soup, drinks"),
        ("Add output", "Keep daily totals clear"),
        ("Net mL", "Review your balance"),
    ]),
    ("03_medicines.png", "Keep medicines organized", "Save schedules, stock counts, and local reminders for each medicine.", "Medicines", AMBER, [
        ("Medicine reminders", "Local notifications"),
        ("Stock 24", "See remaining tablets"),
        ("2x daily", "8:00 AM, 8:00 PM"),
        ("Maintenance", "Track ongoing routines"),
    ]),
    ("04_food.png", "Browse kidney-aware food guidance", "Review general CKD food tips and tailor guidance by profile details.", "Food", "#55a94f", [
        ("Recommended", "White rice, cabbage"),
        ("Limit", "Banana, tomato"),
        ("Avoid", "Soy sauce, instant noodles"),
        ("By CKD stage", "Ask your dietitian"),
    ]),
    ("05_dialysis.png", "Plan dialysis days", "See upcoming sessions and record pre-weight and post-weight notes.", "Dialysis", "#7b5fd0", [
        ("Next session", "Mon, 7:00 AM"),
        ("Record weights", "Pre and post session"),
        ("Upcoming schedule", "Six sessions ahead"),
        ("Clinic details", "Keep address handy"),
    ]),
    ("06_profile.png", "Personalize your care notes", "Optional health profile fields help keep food and fluid context close.", "Health profile", "#2b9e8f", [
        ("CKD stage", "Optional"),
        ("Dialysis status", "Hemo or peritoneal"),
        ("Lab flags", "Potassium, phosphorus"),
        ("Fluid restriction", "Daily limit context"),
    ]),
]


def screenshots():
    for item in SCREENS:
        screenshot(PHONE_DIR / item[0], *item[1:])
    for item in SCREENS[:4]:
        screenshot(TABLET7_DIR / item[0], *item[1:], size=(1200, 1920))
        screenshot(TABLET10_DIR / item[0], *item[1:], size=(1600, 2560))
        wide_screenshot(CHROMEBOOK_DIR / item[0], *item[1:])
        wide_screenshot(XR_DIR / item[0], *item[1:])


def promo_video(master: Image.Image):
    out_path = STORE_DIR / "kidneytrack_promo_1080x1920.mp4"
    frames = []
    duration_per = 72
    for idx, item in enumerate(SCREENS[:5]):
        still = Image.open(PHONE_DIR / item[0]).convert("RGB")
        for f in range(duration_per):
            t = f / duration_per
            zoom = 1.0 + 0.025 * math.sin(t * math.pi)
            crop_w = int(still.width / zoom)
            crop_h = int(still.height / zoom)
            left = (still.width - crop_w) // 2
            top = (still.height - crop_h) // 2
            frame = still.crop((left, top, left + crop_w, top + crop_h)).resize(still.size, Image.Resampling.LANCZOS)
            if f < 10 and idx > 0:
                prev = frames[-1]
                a = f / 10
                frame = Image.blend(Image.fromarray(prev), frame, a)
            frames.append(np.array(frame))
    imageio.mimsave(
        out_path,
        frames,
        fps=24,
        codec="libx264",
        quality=8,
        macro_block_size=1,
    )


def main() -> None:
    ensure_dirs()
    source = Image.open(SOURCE_LOGO)
    master = crop_logo_square(source)
    master.save(BRAND_DIR / "kidneytrack-logo-master.png")
    make_icon(master, 1024, bg="#f7fbfd").save(BRAND_DIR / "kidneytrack-logo-1024.png")
    make_icon(master, 512, bg="#f7fbfd").save(STORE_DIR / "app_icon_512.png")
    save_launcher_icons(master)
    feature_graphic(master)
    screenshots()
    promo_video(master)


if __name__ == "__main__":
    main()
