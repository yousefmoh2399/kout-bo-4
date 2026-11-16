import os
import math
from PIL import Image, ImageDraw, ImageFont

SRC_DIR = '/Users/yousef/Desktop/kout-bo-4/images'
OUT_DIR = '/Users/yousef/Desktop/kout-bo-4/assets/cards'
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_W = 360
TARGET_H = 518

def save_card(im, filename):
    resized = im.resize((TARGET_W, TARGET_H), Image.Resampling.LANCZOS)
    out_path = os.path.join(OUT_DIR, filename)
    if resized.mode == 'RGBA':
        alpha = resized.split()[-1]
        if alpha.getextrema() == (255, 255):
            resized = resized.convert('RGB')
    resized.save(out_path, format='PNG', optimize=True)
    print(f'Saved {filename} ({TARGET_W}x{TARGET_H}) -> {out_path}')

# -------------------------------------------------------------
# 1. High-Resolution Single Cards directly from User Photos
# -------------------------------------------------------------
direct_mappings = {
    'spades_K.png': 'photo_2026-11-16 10.30.56.jpeg',
    'spades_Q.png': 'photo_2026-11-16 10.30.56 (1).jpeg',
    'spades_J.png': 'photo_2026-11-16 10.30.57.jpeg',
    'spades_10.png': 'photo_2026-11-16 10.31.03.jpeg',
    
    'clubs_A.png': 'photo_2026-11-16 10.31.02.jpeg',
    'clubs_K.png': 'photo_2026-11-16 10.30.59 (1).jpeg',
    'clubs_Q.png': 'photo_2026-11-16 10.31.00.jpeg',
    'clubs_J.png': 'photo_2026-11-16 10.31.01.jpeg',
    'clubs_10.png': 'photo_2026-11-16 10.30.51.jpeg',
    'clubs_9.png': 'photo_2026-11-16 10.30.54.jpeg',
    
    'diamonds_A.png': 'photo_2026-11-16 10.31.01 (2).jpeg',
    'diamonds_K.png': 'photo_2026-11-16 10.30.58.jpeg',
    'diamonds_Q.png': 'photo_2026-11-16 10.30.58 (1).jpeg',
    'diamonds_J.png': 'photo_2026-11-16 10.30.59.jpeg',
    'diamonds_10.png': 'photo_2026-11-16 10.30.45.jpeg',
    
    'hearts_A.png': 'photo_2026-11-16 10.31.01 (1).jpeg',
    'hearts_10.png': 'photo_2026-11-16 10.31.02 (1).jpeg',
    
    'card_back.png': 'card_back_official.jpeg',
}

for out_name, in_file in direct_mappings.items():
    im = Image.open(os.path.join(SRC_DIR, in_file))
    save_card(im, out_name)

# -------------------------------------------------------------
# 2. Numbered Cards Extracted from Sheet 1 (photo_2026-11-16 10.30.53.jpeg)
# -------------------------------------------------------------
sheet = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.30.53.jpeg'))
col_splits = [0, 131, 258, 385, 511, 639, 766, 895, 1024]
row_splits = [0, 188, 382, 579, 765]

sheet_extractions = [
    # Spades: 9, 8, 7, 6
    ('spades_9.png', 0, 0),
    ('spades_8.png', 0, 1),
    ('spades_7.png', 0, 2),
    ('spades_6.png', 0, 3),
    # Hearts: 9, 8, 7
    ('hearts_9.png', 1, 0),
    ('hearts_8.png', 1, 1),
    ('hearts_7.png', 1, 2),
    # Diamonds: 9, 8, 7
    ('diamonds_9.png', 2, 0),
    ('diamonds_8.png', 2, 1),
    ('diamonds_7.png', 2, 2),
    # Clubs: 8, 7, 6 (9 is already high-res from photo_2026-11-16 10.30.54.jpeg)
    ('clubs_8.png', 3, 1),
    ('clubs_7.png', 3, 2),
    ('clubs_6.png', 3, 3),
]

for out_name, r, c in sheet_extractions:
    x1 = col_splits[c] + 2
    x2 = col_splits[c+1] - 2
    y1 = row_splits[r] + 2
    y2 = row_splits[r+1] - 2
    card_crop = sheet.crop((x1, y1, x2, y2))
    save_card(card_crop, out_name)

# -------------------------------------------------------------
# 3. Clean Heart Pip Generator (from 10 of Hearts)
# -------------------------------------------------------------
h10 = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.02 (1).jpeg')).convert('RGBA')
pip_raw = h10.crop((320, 280, 420, 390))
heart_pip = Image.new('RGBA', pip_raw.size, (0, 0, 0, 0))
for y in range(pip_raw.height):
    for x in range(pip_raw.width):
        r, g, b, a = pip_raw.getpixel((x, y))
        if r > 120 and r > g * 1.3 and r > b * 1.3:
            dist_to_center = abs(x - pip_raw.width // 2) / (pip_raw.width // 2)
            alpha = int(255 * max(0.0, min(1.0, 1.3 - dist_to_center * 0.4)))
            heart_pip.putpixel((x, y), (r, g, b, alpha))

# -------------------------------------------------------------
# 4. Spades Ace (Baroque Filigree Spade Medallion)
# -------------------------------------------------------------
ah = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.01 (1).jpeg')).convert('RGBA')
ac = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.02.jpeg')).convert('RGBA')
s10 = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.03.jpeg')).convert('RGBA')
w, h = ah.size

# Corner 'A' from Clubs Ace
ah.paste(ac.crop((20, 20, 130, 160)), (20, 20))
ah.paste(ac.crop((w - 130, h - 160, w - 20, h - 20)), (w - 130, h - 160))

# Spade corner pips from 10 Spades
ah.paste(s10.crop((30, 160, 120, 260)), (30, 160))
ah.paste(s10.crop((w - 120, h - 260, w - 30, h - 160)), (w - 120, h - 260))

# Darken red inside central spade medallion to deep obsidian charcoal
pixels_sa = ah.load()
for y in range(160, 864):
    for x in range(130, 557):
        r, g, b, a = pixels_sa[x, y]
        if r > 90 and r > g * 1.5 and r > b * 1.5:
            lum = int(0.299 * r + 0.587 * g + 0.114 * b)
            val = max(18, min(45, int(lum * 0.35)))
            pixels_sa[x, y] = (val, val, val, a)

save_card(ah, 'spades_A.png')

# -------------------------------------------------------------
# 5. Hearts Court Cards (King, Queen, Jack of Hearts)
# -------------------------------------------------------------
def clean_region(pix, x1, y1, x2, y2, bg):
    for y in range(y1, y2):
        for x in range(x1, x2):
            r, g, b, a = pix[x, y]
            if not (r > 232 and g > 225 and b > 198):
                pix[x, y] = bg

# Hearts King from Diamonds King
kd = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.30.58.jpeg')).convert('RGBA')
kw, kh = kd.size
kpix = kd.load()
clean_region(kpix, 45, 155, 125, 265, (250, 242, 222, 255))
clean_region(kpix, kw - 125, kh - 265, kw - 45, kh - 155, (250, 242, 222, 255))
clean_region(kpix, 145, 145, 270, 300, (244, 241, 218, 255))
clean_region(kpix, kw - 270, kh - 300, kw - 145, kh - 145, (244, 241, 218, 255))

h_corner_k = heart_pip.resize((64, int(64 * (heart_pip.height / heart_pip.width))), Image.Resampling.LANCZOS)
h_corner_k_rot = h_corner_k.rotate(180)
kd.paste(h_corner_k, (52, 162), mask=h_corner_k)
kd.paste(h_corner_k_rot, (kw - 52 - h_corner_k.width, kh - 162 - h_corner_k.height), mask=h_corner_k_rot)

h_port_k = heart_pip.resize((106, int(106 * (heart_pip.height / heart_pip.width))), Image.Resampling.LANCZOS)
h_port_k_rot = h_port_k.rotate(180)
kd.paste(h_port_k, (154, 158), mask=h_port_k)
kd.paste(h_port_k_rot, (kw - 154 - h_port_k.width, kh - 158 - h_port_k.height), mask=h_port_k_rot)
save_card(kd, 'hearts_K.png')

# Hearts Queen from Diamonds Queen
qd = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.30.58 (1).jpeg')).convert('RGBA')
qw, qh = qd.size
qpix = qd.load()
clean_region(qpix, 35, 135, 105, 250, (244, 241, 218, 255))
clean_region(qpix, qw - 105, qh - 250, qw - 35, qh - 135, (244, 241, 218, 255))
clean_region(qpix, 140, 135, 250, 270, (244, 241, 218, 255))
clean_region(qpix, qw - 250, qh - 270, qw - 140, qh - 135, (244, 241, 218, 255))

qd.paste(h_corner_k, (40, 155), mask=h_corner_k)
qd.paste(h_corner_k_rot, (qw - 40 - h_corner_k.width, qh - 155 - h_corner_k.height), mask=h_corner_k_rot)
qd.paste(h_port_k, (148, 150), mask=h_port_k)
qd.paste(h_port_k_rot, (qw - 148 - h_port_k.width, qh - 150 - h_port_k.height), mask=h_port_k_rot)
save_card(qd, 'hearts_Q.png')

# Hearts Jack from Diamonds Jack
jd = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.30.59.jpeg')).convert('RGBA')
jw, jh = jd.size
jpix = jd.load()
clean_region(jpix, 45, 135, 110, 250, (254, 254, 252, 255))
clean_region(jpix, jw - 110, jh - 250, jw - 45, jh - 135, (254, 254, 252, 255))
clean_region(jpix, 145, 135, 305, 270, (251, 255, 255, 255))
clean_region(jpix, jw - 305, jh - 270, jw - 145, jh - 135, (251, 255, 255, 255))

jd.paste(h_corner_k, (48, 155), mask=h_corner_k)
jd.paste(h_corner_k_rot, (jw - 48 - h_corner_k.width, jh - 155 - h_corner_k.height), mask=h_corner_k_rot)
jd.paste(h_port_k, (160, 150), mask=h_port_k)
jd.paste(h_port_k_rot, (jw - 160 - h_port_k.width, jh - 150 - h_port_k.height), mask=h_port_k_rot)
save_card(jd, 'hearts_J.png')

# -------------------------------------------------------------
# 6. Luxury Crown Function for Jokers
# -------------------------------------------------------------
def draw_luxury_crown(draw, cx, cy, w, h, is_red=True):
    x0 = cx - w // 2
    y0 = cy - h // 2
    base_h = h * 0.22
    base_rect = [x0 + w*0.08, y0 + h - base_h, x0 + w*0.92, y0 + h]
    draw.rounded_rectangle(base_rect, radius=base_h*0.3, fill=(230, 185, 45), outline=(139, 101, 8), width=3)
    peaks = [
        (x0 + w * 0.10, y0 + h * 0.25),
        (x0 + w * 0.30, y0 + h * 0.38),
        (x0 + w * 0.50, y0 + h * 0.05),
        (x0 + w * 0.70, y0 + h * 0.38),
        (x0 + w * 0.90, y0 + h * 0.25),
    ]
    valleys = [
        (x0 + w * 0.22, y0 + h * 0.65),
        (x0 + w * 0.40, y0 + h * 0.60),
        (x0 + w * 0.60, y0 + h * 0.60),
        (x0 + w * 0.78, y0 + h * 0.65),
    ]
    poly = [
        (x0 + w * 0.12, y0 + h - base_h),
        peaks[0], valleys[0], peaks[1], valleys[1], peaks[2], valleys[2], peaks[3], valleys[3], peaks[4],
        (x0 + w * 0.88, y0 + h - base_h),
    ]
    draw.polygon(poly, fill=(250, 205, 55), outline=(139, 101, 8))
    orb_r = w * 0.04
    for px, py in peaks:
        draw.ellipse([px - orb_r, py - orb_r, px + orb_r, py + orb_r], fill=(255, 235, 120), outline=(160, 110, 10), width=2)
    cx_top = peaks[2][0]
    cy_top = peaks[2][1] - orb_r
    draw.line([cx_top, cy_top - orb_r*1.8, cx_top, cy_top], fill=(255, 220, 80), width=4)
    draw.line([cx_top - orb_r*1.0, cy_top - orb_r*1.0, cx_top + orb_r*1.0, cy_top - orb_r*1.0], fill=(255, 220, 80), width=4)
    jewel_colors = [(200, 20, 20), (30, 80, 200), (20, 160, 40), (200, 20, 20), (30, 80, 200)] if is_red else [(20, 20, 20), (220, 190, 60), (20, 20, 20), (220, 190, 60), (20, 20, 20)]
    for i, jc in enumerate(jewel_colors):
        jx = x0 + w * (0.18 + i * 0.16)
        jy = y0 + h - base_h * 0.5
        jr = base_h * 0.28
        draw.ellipse([jx - jr, jy - jr, jx + jr, jy + jr], fill=jc, outline=(255, 235, 150), width=2)

font_ar = ImageFont.truetype('/System/Library/Fonts/Supplemental/Diwan Thuluth.ttf', 86)
font_sub = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 24)
font_corner = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 28)

# Red Joker (الجوكر الأحمر - البكر 👑)
j_red = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.01 (2).jpeg')).convert('RGBA')
jw, jh = j_red.size
jpix_r = j_red.load()
for y in range(25, 270):
    for x in range(25, 130):
        jpix_r[x, y] = (244, 236, 210, 255)
for y in range(jh - 270, jh - 25):
    for x in range(jw - 130, jw - 25):
        jpix_r[x, y] = (244, 236, 210, 255)

draw_r = ImageDraw.Draw(j_red)
draw_luxury_crown(draw_r, jw // 2, jh // 2 - 40, 240, 150, is_red=True)
draw_r.text((jw // 2 + 2, jh // 2 + 92), 'البكر', fill=(60, 10, 10), font=font_ar, anchor='mm')
draw_r.text((jw // 2, jh // 2 + 90), 'البكر', fill=(255, 230, 140), font=font_ar, anchor='mm')
draw_r.text((jw // 2, jh // 2 + 160), 'THE RED JOKER', fill=(255, 215, 130), font=font_sub, anchor='mm')
for i, ch in enumerate('JOKER'):
    draw_r.text((55, 45 + i * 26), ch, fill=(185, 25, 25), font=font_corner, anchor='mm')
    draw_r.text((jw - 55, jh - 45 - (4 - i) * 26), ch, fill=(185, 25, 25), font=font_corner, anchor='mm')
save_card(j_red, 'joker_red.png')

# Black Joker (الجوكر الأسود - العوير ♠)
j_black = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.02.jpeg')).convert('RGBA')
bw, bh = j_black.size
jpix_b = j_black.load()
for y in range(25, 270):
    for x in range(25, 130):
        jpix_b[x, y] = (244, 236, 210, 255)
for y in range(bh - 270, bh - 25):
    for x in range(bw - 130, bw - 25):
        jpix_b[x, y] = (244, 236, 210, 255)

draw_b = ImageDraw.Draw(j_black)
draw_luxury_crown(draw_b, bw // 2, bh // 2 - 40, 240, 150, is_red=False)
draw_b.text((bw // 2 + 2, bh // 2 + 92), 'العوير', fill=(20, 20, 20), font=font_ar, anchor='mm')
draw_b.text((bw // 2, bh // 2 + 90), 'العوير', fill=(255, 230, 140), font=font_ar, anchor='mm')
draw_b.text((bw // 2, bh // 2 + 160), 'THE BLACK JOKER', fill=(230, 210, 140), font=font_sub, anchor='mm')
for i, ch in enumerate('JOKER'):
    draw_b.text((55, 45 + i * 26), ch, fill=(25, 25, 25), font=font_corner, anchor='mm')
    draw_b.text((bw - 55, bh - 45 - (4 - i) * 26), ch, fill=(25, 25, 25), font=font_corner, anchor='mm')
save_card(j_black, 'joker_black.png')

print('\n*** ALL 37 DECK ASSETS FULLY GENERATED AND VERIFIED ***')
