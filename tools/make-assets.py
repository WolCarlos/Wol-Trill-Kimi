# ============================================================================
# Wol-Trill-Kimi — make-assets.py
# Lavora le immagini della mascotte:
#   1. sfondo nero -> trasparente (flood-fill dai bordi: il nero interno resta)
#   2. trim dei bordi vuoti
#   3. social preview GitHub 1280x640 (assets/social-preview.png)
# Uso: python tools/make-assets.py <src_quadrata> <src_verticale>
# ============================================================================
import os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
os.makedirs(ASSETS, exist_ok=True)

def black_to_alpha(img, thresh=40):
    """Rende trasparente il nero contiguo ai bordi (il nero interno alla sticker resta)."""
    img = img.convert("RGBA")
    mask = Image.new("L", img.size, 0)          # 255 = sfondo da rimuovere
    draw = ImageDraw.Draw(mask)
    rgb = img.convert("RGB")
    px = rgb.load()
    w, h = img.size

    # maschera dei pixel quasi-neri
    near_black = Image.new("1", img.size, 0)
    nb = near_black.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if r < thresh and g < thresh and b < thresh:
                nb[x, y] = 1

    # flood fill dai 4 angoli sulla maschera dei quasi-neri
    for seed in [(0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1),
                 (w // 2, 0), (w // 2, h - 1), (0, h // 2), (w - 1, h // 2)]:
        if nb[seed]:
            ImageDraw.floodfill(near_black, seed, 2)   # 2 = sfondo raggiunto
    nb = near_black.load()
    m = mask.load()
    for y in range(h):
        for x in range(w):
            if nb[x, y] == 2:
                m[x, y] = 255

    # ammorbidisci i bordi della maschera
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))

    out = img.copy()
    out.putalpha(Image.eval(mask, lambda a: 255 - a))
    return out

def trim(img, pad=10):
    bbox = img.getbbox()
    if not bbox:
        return img
    l, t, r, b = bbox
    l = max(0, l - pad); t = max(0, t - pad)
    r = min(img.width, r + pad); b = min(img.height, b + pad)
    return img.crop((l, t, r, b))

def load_font(size):
    for f in ["C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/segoeuib.ttf",
              "C:/Windows/Fonts/arial.ttf"]:
        if os.path.exists(f):
            return ImageFont.truetype(f, size)
    return ImageFont.load_default()

def main(src_square, src_tall):
    # --- 1+2: trasparenza + trim ---
    for src, name in [(src_square, "mascotte.png"), (src_tall, "mascotte-tall.png")]:
        im = trim(black_to_alpha(Image.open(src)))
        im.save(os.path.join(ASSETS, name))
        print(f"{name}: {im.size}")

    # --- 3: social preview 1280x640 ---
    W, H = 1280, 640
    bg = Image.new("RGB", (W, H), (20, 22, 29))
    # leggero gradiente verticale
    top, bot = (24, 27, 38), (13, 14, 20)
    for y in range(H):
        f = y / H
        ImageDraw.Draw(bg).line([(0, y), (W, y)],
            fill=tuple(int(top[i] + (bot[i] - top[i]) * f) for i in range(3)))

    mascot = Image.open(os.path.join(ASSETS, "mascotte-tall.png"))
    mh = 560
    mw = int(mascot.width * mh / mascot.height)
    mascot = mascot.resize((mw, mh), Image.LANCZOS)
    bg.paste(mascot, (W - mw - 60, (H - mh) // 2), mascot)

    d = ImageDraw.Draw(bg)
    d.text((70, 210), "Wol-Trill-Kimi", font=load_font(92), fill=(255, 198, 109))
    d.text((74, 330), "Sound & visual notifications for Kimi Code",
           font=load_font(38), fill=(232, 234, 240))
    d.text((74, 395), "Windows · macOS · Linux — VS Code & CLI",
           font=load_font(30), fill=(154, 160, 176))
    d.text((74, 445), "github.com/WolCarlos/Wol-Trill-Kimi",
           font=load_font(26), fill=(123, 224, 139))
    bg.save(os.path.join(ASSETS, "social-preview.png"))
    print("social-preview.png: 1280x640")

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
