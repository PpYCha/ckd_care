from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "store_assets" / "actual_raw"
STORE_DIR = ROOT / "store_assets"
PHONE_DIR = STORE_DIR / "phone"
TABLET7_DIR = STORE_DIR / "tablet_7_inch"
TABLET10_DIR = STORE_DIR / "tablet_10_inch"
CHROMEBOOK_DIR = STORE_DIR / "chromebook"
XR_DIR = STORE_DIR / "android_xr"

BG = "#f7fbfd"


RAW_FILES = [
    ("01_home.png", "01_home_actual_android.png"),
    ("02_fluid.png", "02_fluid_actual_android.png"),
    ("03_meds.png", "03_medicines_actual_android.png"),
    ("04_food.png", "04_food_actual_android.png"),
    ("05_settings.png", "05_settings_actual_android.png"),
]


def fit_on_canvas(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    canvas = Image.new("RGB", size, BG)
    draw = ImageDraw.Draw(canvas)
    target_h = int(size[1] * 0.94)
    target_w = int(src.width * target_h / src.height)
    if target_w > int(size[0] * 0.82):
        target_w = int(size[0] * 0.82)
        target_h = int(src.height * target_w / src.width)
    shot = src.resize((target_w, target_h), Image.Resampling.LANCZOS).convert("RGB")
    x = (size[0] - target_w) // 2
    y = (size[1] - target_h) // 2
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (x + 16, y + 18, x + target_w + 16, y + target_h + 18),
        radius=36,
        fill=(24, 58, 78, 45),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    canvas = Image.alpha_composite(canvas.convert("RGBA"), shadow).convert("RGB")
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (x - 8, y - 8, x + target_w + 8, y + target_h + 8),
        radius=34,
        fill="#d8eaf0",
    )
    canvas.paste(shot, (x, y))
    return canvas


def crop_phone(src: Image.Image) -> Image.Image:
    src = src.convert("RGB")
    # Google Play phone assets need 9:16 or 16:9. The emulator is 1080x2340,
    # so crop to the top 1080x1920 app view where the real UI content sits.
    return src.crop((0, 0, 1080, 1920))


def main() -> None:
    for folder in [PHONE_DIR, TABLET7_DIR, TABLET10_DIR, CHROMEBOOK_DIR, XR_DIR]:
        folder.mkdir(parents=True, exist_ok=True)

    raw_images: list[tuple[str, Image.Image]] = []
    for raw_name, out_name in RAW_FILES:
        src = Image.open(RAW_DIR / raw_name).convert("RGB")
        raw_images.append((out_name, src))
        crop_phone(src).save(PHONE_DIR / out_name, quality=95)

    for out_name, src in raw_images[:4]:
        fit_on_canvas(src, (1200, 1920)).save(TABLET7_DIR / out_name, quality=95)
        fit_on_canvas(src, (1600, 2560)).save(TABLET10_DIR / out_name, quality=95)
        fit_on_canvas(src, (1920, 1080)).save(CHROMEBOOK_DIR / out_name, quality=95)
        fit_on_canvas(src, (1920, 1080)).save(XR_DIR / out_name, quality=95)


if __name__ == "__main__":
    main()
