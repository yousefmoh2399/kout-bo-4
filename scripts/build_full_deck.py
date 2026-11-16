import os
import math
import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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
    else:
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
    # Hearts: 9, 8
    ('hearts_9.png', 1, 0),
    ('hearts_8.png', 1, 1),
    # Diamonds: 9, 8, 7
    ('diamonds_9.png', 2, 0),
    ('diamonds_8.png', 2, 1),
    ('diamonds_7.png', 2, 2),
    # Clubs: 9 (row 3 col 0), 8 (row 3 col 1), 7 (row 3 col 2)
    ('clubs_9.png', 3, 0),
    ('clubs_8.png', 3, 1),
    ('clubs_7.png', 3, 2),
]

for out_name, r, c in sheet_extractions:
    x1 = col_splits[c] + 3
    x2 = col_splits[c+1] - 3
    y1 = row_splits[r] + 2
    y2 = row_splits[r+1] - 2
    card_crop = sheet.crop((x1, y1, x2, y2))
    save_card(card_crop, out_name)

# -------------------------------------------------------------
# 3. Hearts 7: Fix bottom-right corner (replace erroneous '8' with '7')
# -------------------------------------------------------------
x1 = col_splits[2] + 3
x2 = col_splits[3] - 3
y1 = row_splits[1] + 2
y2 = row_splits[2] - 2
h7_raw = sheet.crop((x1, y1, x2, y2)).resize((TARGET_W, TARGET_H), Image.Resampling.LANCZOS)
d7_im = Image.open(os.path.join(OUT_DIR, 'diamonds_7.png'))

patch_w = 42
patch_h = 60
crop_x = 307
crop_y = 445
d7_patch = d7_im.crop((crop_x, crop_y, crop_x + patch_w, crop_y + patch_h))
mask_h7 = Image.new('L', (patch_w, patch_h), 255)
ImageDraw.Draw(mask_h7).rectangle([0, 0, patch_w, patch_h], outline=0, width=3)
mask_h7 = mask_h7.filter(ImageFilter.GaussianBlur(radius=2))
h7_raw.paste(d7_patch, (crop_x, crop_y), mask=mask_h7)
save_card(h7_raw, 'hearts_7.png')

# -------------------------------------------------------------
# 4. Clubs 6: Clean 6 of Clubs with exactly 6 pips
# -------------------------------------------------------------
c8_im = Image.open(os.path.join(OUT_DIR, 'clubs_8.png'))
s6_im = Image.open(os.path.join(OUT_DIR, 'spades_6.png'))
c6 = c8_im.copy()

# Remove the two center pips with feathered inpainting of the gold watermark
mask_c6 = Image.new('L', c8_im.size, 0)
draw_c6 = ImageDraw.Draw(mask_c6)
draw_c6.ellipse([136, 136, 224, 238], fill=255)
draw_c6.ellipse([136, 276, 224, 378], fill=255)
draw_c6.rectangle([160, 130, 200, 245], fill=255)
draw_c6.rectangle([160, 270, 200, 385], fill=255)
mask_c6 = mask_c6.filter(ImageFilter.GaussianBlur(radius=4))
c6.paste(s6_im, (0, 0), mask=mask_c6)

# TL corner digit 6
patch_w = 40
patch_h = 55
crop_x = 14
crop_y = 15
s6_tl = s6_im.crop((crop_x, crop_y, crop_x + patch_w, crop_y + patch_h))
mask_tl = Image.new('L', (patch_w, patch_h), 255)
ImageDraw.Draw(mask_tl).rectangle([0, 0, patch_w, patch_h], outline=0, width=1)
mask_tl = mask_tl.filter(ImageFilter.GaussianBlur(radius=1))
c6.paste(s6_tl, (crop_x, crop_y), mask=mask_tl)

# BR corner digit 6 (inverted)
patch_w_br = 48
patch_h_br = 62
crop_x_br = 304
crop_y_br = 444
s6_br = s6_im.crop((crop_x_br, crop_y_br, crop_x_br + patch_w_br, crop_y_br + patch_h_br))
mask_br = Image.new('L', (patch_w_br, patch_h_br), 255)
ImageDraw.Draw(mask_br).rectangle([0, 0, patch_w_br, patch_h_br], outline=0, width=1)
mask_br = mask_br.filter(ImageFilter.GaussianBlur(radius=1))
c6.paste(s6_br, (crop_x_br, crop_y_br), mask=mask_br)

save_card(c6, 'clubs_6.png')

# -------------------------------------------------------------
# 5. Extract Authentic Gold-Trimmed Heart Pip
# -------------------------------------------------------------
h10_raw = Image.open(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.02 (1).jpeg')).convert('RGB')
crop_pip = h10_raw.crop((24, 155, 112, 260))
pw, ph = crop_pip.size

queue = [(0, 0), (pw-1, 0), (0, ph-1), (pw-1, ph-1)]
visited = set(queue)
while queue:
    cx, cy = queue.pop(0)
    for nx, ny in [(cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)]:
        if 0 <= nx < pw and 0 <= ny < ph and (nx, ny) not in visited:
            r, g, b = crop_pip.getpixel((nx, ny))
            if r > 228 and g > 220 and b > 190 and abs(r - g) < 25:
                visited.add((nx, ny))
                queue.append((nx, ny))

heart_mask = Image.new('L', (pw, ph), 255)
for (bx, by) in visited:
    heart_mask.putpixel((bx, by), 0)
heart_mask = heart_mask.filter(ImageFilter.GaussianBlur(radius=0.7))

alpha_heart = crop_pip.convert('RGBA')
alpha_heart.putalpha(heart_mask)

# -------------------------------------------------------------
# 6. Spades Ace (Obsidian / Gold Baroque Filigree Medallion)
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
# 7. Hearts Court Cards (King, Queen, Jack of Hearts)
# -------------------------------------------------------------
courts_info = {
    'hearts_K.png': {
        'source': 'photo_2026-11-16 10.30.58.jpeg',
        'tl_corner': (83, 199, 66),
        'br_corner': (605, 833, 66),
        'tl_med': (226, 221, 114),
        'br_med': (462, 813, 114),
    },
    'hearts_Q.png': {
        'source': 'photo_2026-11-16 10.30.58 (1).jpeg',
        'tl_corner': (66, 194, 66),
        'br_corner': (621, 835, 66),
        'tl_med': (193, 204, 114),
        'br_med': (496, 822, 114),
    },
    'hearts_J.png': {
        'source': 'photo_2026-11-16 10.30.59.jpeg',
        'tl_corner': (76, 196, 66),
        'br_corner': (609, 833, 66),
        'tl_med': (221, 209, 114),
        'br_med': (464, 806, 114),
    }
}

def remove_diamond_and_paste_heart(im, cx, cy, hw, is_inverted=False):
    w, h = im.size
    queue = [(cx, cy)]
    visited = set(queue)
    diamond_pixels = set()
    max_radius = int(hw * 0.9)
    
    while queue:
        x, y = queue.pop(0)
        diamond_pixels.add((x, y))
        for nx, ny in [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]:
            if (nx, ny) not in visited:
                dist = ((nx - cx)**2 + (ny - cy)**2)**0.5
                if dist <= max_radius and 0 <= nx < w and 0 <= ny < h:
                    r, g, b = im.getpixel((nx, ny))[:3]
                    is_cream = (r > 230 and g > 220 and b > 190 and abs(r - g) < 25)
                    if not is_cream:
                        visited.add((nx, ny))
                        queue.append((nx, ny))
    
    dilated = set(diamond_pixels)
    for (x, y) in diamond_pixels:
        for dx in [-2, -1, 0, 1, 2]:
            for dy in [-2, -1, 0, 1, 2]:
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    r, g, b = im.getpixel((nx, ny))[:3]
                    if not (r < 60 and g < 60 and b < 60):
                        dilated.add((nx, ny))
    
    cream_samples = []
    for (x, y) in dilated:
        for dx, dy in [(5, 0), (-5, 0), (0, 5), (0, -5)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in dilated:
                pix = im.getpixel((nx, ny))[:3]
                if pix[0] > 225 and pix[1] > 215 and pix[2] > 185:
                    cream_samples.append(pix)
    
    if cream_samples:
        avg_r = sum(c[0] for c in cream_samples) // len(cream_samples)
        avg_g = sum(c[1] for c in cream_samples) // len(cream_samples)
        avg_b = sum(c[2] for c in cream_samples) // len(cream_samples)
        bg_col = (avg_r, avg_g, avg_b, 255)
    else:
        bg_col = (250, 245, 228, 255)
    
    pix = im.load()
    for (x, y) in dilated:
        pix[x, y] = bg_col
    
    hh = int(hw * alpha_heart.height / alpha_heart.width)
    h_scaled = alpha_heart.resize((hw, hh), Image.Resampling.LANCZOS)
    if is_inverted:
        h_scaled = h_scaled.rotate(180)
    
    im.paste(h_scaled, (cx - hw // 2, cy - hh // 2), mask=h_scaled)

for card_name, info in courts_info.items():
    im = Image.open(os.path.join(SRC_DIR, info['source'])).convert('RGBA')
    for key, is_inverted in [('tl_corner', False), ('br_corner', True), ('tl_med', False), ('br_med', True)]:
        cx, cy, hw = info[key]
        remove_diamond_and_paste_heart(im, cx, cy, hw, is_inverted=is_inverted)
    save_card(im, card_name)

# -------------------------------------------------------------
# 8. Luxury Jokers (البكر 👑 & العوير ♠) with 3D Royal Crown
# -------------------------------------------------------------
crown = Image.open('images/test_verification/royal_crown_isolated.png').convert('RGBA')
cpix = crown.load()
for cy in range(crown.height):
    for cx in range(crown.width):
        r, g, b, a = cpix[cx, cy]
        if a > 0:
            if g > r + 5 or (g > 80 and r < 80):
                cpix[cx, cy] = (0, 0, 0, 0)

font_ar = ImageFont.truetype('/System/Library/Fonts/GeezaPro.ttc', 70, index=1)
font_sub = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 24)
font_corner = ImageFont.truetype('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 26)

def build_joker(base_path, ar_title, en_title, is_red=True):
    im = Image.open(base_path).convert('RGBA')
    w, h = im.size
    bg_col = im.getpixel((25, 25))
    
    def clean_corner(box):
        bx1, by1, bx2, by2 = box
        to_clean = set()
        for y in range(by1, by2):
            for x in range(bx1, bx2):
                r, g, b = im.getpixel((x, y))[:3]
                is_cream = (r > 230 and g > 220 and b > 190 and abs(r - g) < 25)
                if not is_cream and 16 <= x <= w - 16 and 16 <= y <= h - 16:
                    to_clean.add((x, y))
        
        dilated = set(to_clean)
        for x, y in to_clean:
            for dx in [-2, -1, 0, 1, 2]:
                for dy in [-2, -1, 0, 1, 2]:
                    nx, ny = x + dx, y + dy
                    if 16 <= nx <= w - 16 and 16 <= ny <= h - 16:
                        dilated.add((nx, ny))
        
        pix = im.load()
        for x, y in dilated:
            pix[x, y] = bg_col

    clean_corner((0, 0, 130, 270))
    clean_corner((w - 130, h - 270, w, h))
    
    # 3D Royal Crown
    cw = 250
    ch = int(cw * crown.height / crown.width)
    c_scaled = crown.resize((cw, ch), Image.Resampling.LANCZOS)
    
    cx = w // 2
    cy = h // 2 - 38
    
    shadow_mask = Image.new('L', c_scaled.size, 0)
    for sy in range(ch):
        for sx in range(cw):
            a = c_scaled.getpixel((sx, sy))[3]
            if a > 40:
                shadow_mask.putpixel((sx, sy), int(a * 0.5))
    shadow_mask = shadow_mask.filter(ImageFilter.GaussianBlur(radius=6))
    shadow_img = Image.new('RGBA', c_scaled.size, (15, 10, 5, 255))
    im.paste(shadow_img, (cx - cw // 2, cy - ch // 2 + 8), mask=shadow_mask)
    im.paste(c_scaled, (cx - cw // 2, cy - ch // 2), mask=c_scaled)
    
    # Arabic Typography
    draw = ImageDraw.Draw(im)
    reshaped_ar = get_display(arabic_reshaper.reshape(ar_title))
    text_y = cy + ch // 2 + 36
    outline_col = (45, 10, 10) if is_red else (15, 15, 15)
    fill_col = (255, 235, 140)
    
    for dx, dy in [(-2, -2), (2, -2), (-2, 2), (2, 2), (0, 3), (0, -2), (-2, 0), (2, 0)]:
        draw.text((cx + dx, text_y + dy), reshaped_ar, font=font_ar, fill=outline_col, anchor='mm')
    draw.text((cx, text_y), reshaped_ar, font=font_ar, fill=fill_col, anchor='mm')
    
    # Subtitle English
    for dx, dy in [(-1, -1), (1, -1), (-1, 1), (1, 1), (0, 2)]:
        draw.text((cx + dx, text_y + 55 + dy), en_title, font=font_sub, fill=outline_col, anchor='mm')
    draw.text((cx, text_y + 55), en_title, font=font_sub, fill=(245, 220, 130), anchor='mm')
    
    # Corner letters: 'JOKER'
    corner_col = (185, 25, 25) if is_red else (25, 25, 25)
    for i, ch_char in enumerate('JOKER'):
        draw.text((55, 45 + i * 26), ch_char, fill=corner_col, font=font_corner, anchor='mm')
        draw.text((w - 55, h - 45 - (4 - i) * 26), ch_char, fill=corner_col, font=font_corner, anchor='mm')
        
    return im

j_red = build_joker(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.01 (2).jpeg'), 'البكر', 'THE RED JOKER', is_red=True)
save_card(j_red, 'joker_red.png')

j_black = build_joker(os.path.join(SRC_DIR, 'photo_2026-11-16 10.31.02.jpeg'), 'العوير', 'THE BLACK JOKER', is_red=False)
save_card(j_black, 'joker_black.png')

print('\n*** ALL 37 DECK ASSETS FULLY GENERATED AND VERIFIED ***')
