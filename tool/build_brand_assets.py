"""Build exact SuperCampus raster assets from the approved logo exports."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
RESAMPLE = Image.Resampling.LANCZOS


def remove_flat_background(source: Path, *, light: bool) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    pixels = []
    for red, green, blue, _ in image.getdata():
        distance = 255 - min(red, green, blue) if light else max(red, green, blue)
        alpha = max(0, min(255, (distance - 2) * 28))
        pixels.append((red, green, blue, alpha))
    image.putdata(pixels)
    return image


def square_mark(image: Image.Image, size: int, fill: float = 0.76) -> Image.Image:
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("The approved logo image contains no visible mark")
    cropped = image.crop(bounds)
    target = round(size * fill)
    scale = min(target / cropped.width, target / cropped.height)
    resized = cropped.resize(
        (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale))),
        RESAMPLE,
    )
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.alpha_composite(
        resized,
        ((size - resized.width) // 2, (size - resized.height) // 2),
    )
    return canvas


def save(image: Image.Image, path: Path, size: int | None = None) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    output = image if size is None else image.resize((size, size), RESAMPLE)
    output.save(path, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gradient-on-white", type=Path, required=True)
    parser.add_argument("--black-on-white", type=Path, required=True)
    parser.add_argument("--white-on-black", type=Path, required=True)
    parser.add_argument("--app-icon", type=Path, required=True)
    args = parser.parse_args()

    gradient = square_mark(remove_flat_background(args.gradient_on_white, light=True), 1024)
    black = square_mark(remove_flat_background(args.black_on_white, light=True), 1024)
    white = square_mark(remove_flat_background(args.white_on_black, light=False), 1024)
    app_icon = Image.open(args.app_icon).convert("RGB").resize((1024, 1024), RESAMPLE)

    branding = ROOT / "assets" / "branding"
    save(gradient, branding / "supercampus_mark_gradient.png")
    save(black, branding / "supercampus_mark_black.png")
    save(white, branding / "supercampus_mark_white.png")
    save(app_icon, branding / "supercampus_app_icon.png")
    save(white, ROOT / "assets" / "images" / "login_success_watermark.png")

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, pixels in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        save(app_icon, android / f"mipmap-{density}" / "ic_launcher.png", pixels)
    for density, scale in {
        "mdpi": 1.0,
        "hdpi": 1.5,
        "xhdpi": 2.0,
        "xxhdpi": 3.0,
        "xxxhdpi": 4.0,
    }.items():
        # Preserve the complete approved square artwork for the launcher and
        # native splash. Android supplies the required output dimensions; no
        # cropping or extra mark scaling is applied here.
        save(app_icon, android / f"drawable-{density}" / "launch_image.png", round(144 * scale))
        save(white, android / f"drawable-{density}" / "ic_notification.png", round(24 * scale))
        save(
            app_icon,
            android / f"mipmap-{density}" / "ic_launcher_foreground.png",
            round(108 * scale),
        )

    ios_icons = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    contents = json.loads((ios_icons / "Contents.json").read_text(encoding="utf-8"))
    for entry in contents["images"]:
        filename = entry.get("filename")
        logical = entry.get("size")
        scale = entry.get("scale", "1x")
        if not filename or not logical:
            continue
        pixels = round(float(logical.split("x")[0]) * float(scale.removesuffix("x")))
        save(app_icon, ios_icons / filename, pixels)

    ios_launch = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for scale, pixels in (("", 168), ("@2x", 336), ("@3x", 504)):
        save(app_icon, ios_launch / f"LaunchImage{scale}.png", pixels)

    mac_icons = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for pixels in (16, 32, 64, 128, 256, 512, 1024):
        save(app_icon, mac_icons / f"app_icon_{pixels}.png", pixels)

    windows_icon = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    app_icon.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )

    web = ROOT / "web"
    save(app_icon, web / "favicon.png", 32)
    save(app_icon, web / "icons" / "Icon-192.png", 192)
    save(app_icon, web / "icons" / "Icon-512.png", 512)
    save(app_icon, web / "icons" / "Icon-maskable-192.png", 192)
    save(app_icon, web / "icons" / "Icon-maskable-512.png", 512)


if __name__ == "__main__":
    main()
