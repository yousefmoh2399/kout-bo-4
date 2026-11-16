import os
import math
import arabic_reshaper
from bidi.algorithm import get_display
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SRC_DIR = '/Users/yousef/Desktop/kout-bo-4/images'
TEMPLATE_DIR = '/Users/yousef/Desktop/kout-bo-4/images/templates'
OUT_DIR = '/Users/yousef/Desktop/kout-bo-4/assets/cards'
os.makedirs(OUT_DIR, exist_ok=True)

TARGET_W = 687
TARGET_H = 1024

def save_card(im, filename):
    if im.size != (TARGET_W, TARGET_H):
        resized = im.resize((TARGET_W, TARGET_H), Image.Resampling.LANCZOS)
    else:
        resized = im
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
# 1. Native High-Resolution Master Cards directly from User Photos
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
# 2. Numbered Cards (6, 7, 8, 9) Reconstructed at Native 687x1024
# -------------------------------------------------------------
base_canvas = Image.open(os.path.join(TEMPLATE_DIR, 'pristine_canvas.png')).convert('RGBA')

# Font: Bodoni 72 Bold (authentic deck typography)
font_digit = None
for f_path, f_idx in [
    ('/System/Library/Fonts/Supplemental/Bodoni 72.ttc', 2),
    ('/System/Library/Fonts/Supplemental/Times New Roman Bold.ttf', 0),
    ('/System/Library/Fonts/Times.ttc', 1),
]:
    if os.path.exists(f_path):
        font_digit = ImageFont.truetype(f_path, 110, index=f_idx)
        break

pips_config = {
    'spades': {
        'pip': Image.open(os.path.join(TEMPLATE_DIR, 'spade_pip.png')).convert('RGBA'),
        'color': (20, 20, 20, 255),
        'ranks': ['6', '7', '8', '9'],
        'cw': 126,
    },
    'clubs': {
        'pip': Image.open(os.path.join(TEMPLATE_DIR, 'club_pip.png')).convert('RGBA'),
        'color': (20, 20, 20, 255),
        'ranks': ['6', '7', '8', '9'],
        'cw': 126,
    },
    'diamonds': {
        'pip': Image.open(os.path.join(TEMPLATE_DIR, 'diamond_pip.png')).convert('RGBA'),
        'color': (165, 24, 32, 255),
        'ranks': ['7', '8', '9'],
        'cw': 118,
    },
    'hearts': {
        'pip': Image.open(os.path.join(TEMPLATE_DIR, 'heart_pip.png')).convert('RGBA'),
        'color': (168, 26, 34, 255),
        'ranks': ['7', '8', '9'],
        'cw': 122,
    },
}

card_layouts = {
    '6': [
        (197, 228, False), (488, 228, False),
        (197, 512, False), (488, 512, False),
        (197, 795, True),  (488, 795, True),
    ],
    '7': [
        (197, 228, False), (488, 228, False),
        (343, 370, False),
        (197, 512, False), (488, 512, False),
        (197, 795, True),  (488, 795, True),
    ],
    '8': [
        (197, 228, False), (488, 228, False),
        (343, 370, False),
        (197, 512, False), (488, 512, False),
        (343, 654, True),
        (197, 795, True),  (488, 795, True),
    ],
    '9': [
        (197, 218, False), (488, 218, False),
        (197, 414, False), (488, 414, False),
        (343, 512, False),
        (197, 610, True),  (488, 610, True),
        (197, 806, True),  (488, 806, True),
    ]
}

for suit, sinfo in pips_config.items():
    raw_pip = sinfo['pip']
    cw = sinfo['cw']
    ch = int(cw * raw_pip.height / raw_pip.width)
    p_center = raw_pip.resize((cw, ch), Image.Resampling.LANCZOS)
    p_center_inv = p_center.rotate(180)
    
    pw = 58
    ph = int(pw * raw_pip.height / raw_pip.width)
    p_corner = raw_pip.resize((pw, ph), Image.Resampling.LANCZOS)
    p_corner_inv = p_corner.rotate(180)
    
    col = sinfo['color']
    
    for r in sinfo['ranks']:
        card = base_canvas.copy()
        draw = ImageDraw.Draw(card)
        
        # TL Numeral & Pip
        draw.text((72, 80), r, font=font_digit, fill=col, anchor='mm')
        card.paste(p_corner, (72 - pw // 2, 185 - ph // 2), mask=p_corner)
        
        # BR Numeral & Pip (180 deg inverted)
        digit_im = Image.new('RGBA', (130, 150), (0, 0, 0, 0))
        ImageDraw.Draw(digit_im).text((65, 75), r, font=font_digit, fill=col, anchor='mm')
        digit_inv = digit_im.rotate(180)
        card.paste(digit_inv, (TARGET_W - 72 - 65, TARGET_H - 80 - 75), mask=digit_inv)
        card.paste(p_corner_inv, (TARGET_W - 72 - pw // 2, TARGET_H - 185 - ph // 2), mask=p_corner_inv)
        
        # Central pips
        for cx, cy, is_inv in card_layouts[r]:
            p_use = p_center_inv if is_inv else p_center
            card.paste(p_use, (cx - cw // 2, cy - ch // 2), mask=p_use)
            
        save_card(card, f'{suit}_{r}.png')

# -------------------------------------------------------------
# 3. Spades Ace (Obsidian / Gold Baroque Filigree Medallion)
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
# 4. Hearts Court Cards (King, Queen, Jack of Hearts)
# -------------------------------------------------------------
alpha_heart = Image.open(os.path.join(TEMPLATE_DIR, 'heart_pip.png')).convert('RGBA')

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
# 5. Luxury Jokers (البكر 👑 & العوير ♠) with 3D Royal Crown
# -------------------------------------------------------------
crown = Image.open(os.path.join(TEMPLATE_DIR, 'royal_crown.png')).convert('RGBA')
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

print('\n*** ALL 37 DECK ASSETS FULLY GENERATED AT NATIVE 687x1024 RESOLUTION ***')
