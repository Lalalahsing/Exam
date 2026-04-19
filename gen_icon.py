"""
生成國中會考分析 App Icon（1024×1024）
設計概念：深藍漸層背景 + 考卷卡片 + 五科彩色答題條 + 放大鏡（AI分析）
"""
from PIL import Image, ImageDraw, ImageFilter
import math

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# ── 1. 背景漸層（深靛藍 → 深海藍）──────────────────────────────
for y in range(SIZE):
    t = y / SIZE
    r = int(15  + (28  - 15)  * t)
    g = int(50  + (80  - 50)  * t)
    b = int(140 + (170 - 140) * t)
    draw.rectangle([(0, y), (SIZE, y + 1)], fill=(r, g, b, 255))

# ── 2. 輔助函式 ──────────────────────────────────────────────────
def rounded_rect(draw, xy, r, fill, stroke=None, stroke_width=0):
    x0, y0, x1, y1 = xy
    draw.rounded_rectangle([x0, y0, x1, y1], radius=r, fill=fill,
                            outline=stroke, width=stroke_width)

def lerp_color(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))

# ── 3. 背景光暈（柔和藍紫）───────────────────────────────────────
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
gd = ImageDraw.Draw(glow)
gd.ellipse([120, 80, 800, 650], fill=(80, 130, 255, 45))
glow = glow.filter(ImageFilter.GaussianBlur(radius=90))
img = Image.alpha_composite(img, glow)
draw = ImageDraw.Draw(img)

# ── 4. 考卷卡片（白色圓角矩形）──────────────────────────────────
CARD_L, CARD_T = 158, 110
CARD_R, CARD_B = 866, 810
CARD_RADIUS = 56

# 陰影層
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
sd.rounded_rectangle([CARD_L + 8, CARD_T + 14, CARD_R + 8, CARD_B + 14],
                     radius=CARD_RADIUS, fill=(0, 0, 0, 70))
shadow = shadow.filter(ImageFilter.GaussianBlur(radius=18))
img = Image.alpha_composite(img, shadow)
draw = ImageDraw.Draw(img)

# 卡片本體
draw.rounded_rectangle([CARD_L, CARD_T, CARD_R, CARD_B],
                        radius=CARD_RADIUS, fill=(245, 248, 255, 255))

# ── 5. 標題列（深藍色頂部橫條）──────────────────────────────────
HEADER_H = 100
draw.rounded_rectangle([CARD_L, CARD_T, CARD_R, CARD_T + HEADER_H + CARD_RADIUS],
                        radius=CARD_RADIUS, fill=(24, 62, 148, 255))
draw.rectangle([CARD_L, CARD_T + HEADER_H // 2, CARD_R, CARD_T + HEADER_H],
               fill=(24, 62, 148, 255))

# 標題小橫線（模擬文字）
for i, w in enumerate([180, 120]):
    x0 = CARD_L + 44 + i * (180 + 20)
    draw.rounded_rectangle([x0, CARD_T + 36, x0 + w, CARD_T + 58],
                            radius=8, fill=(255, 255, 255, 200))

# ── 6. 五科答題進度條 ────────────────────────────────────────────
SUBJECTS = [
    ("數學", (76,  175,  80),  0.72),   # 綠
    ("英語", (33,  150, 243),  0.85),   # 藍
    ("國文", (156,  39, 176),  0.60),   # 紫
    ("社會", (255, 152,   0),  0.78),   # 橙
    ("自然", (0,   188, 212),  0.55),   # 青
]

BAR_X0     = CARD_L + 44
BAR_MAX_W  = (CARD_R - CARD_L) - 88 - 60
BAR_H      = 46
BAR_GAP    = 24
START_Y    = CARD_T + HEADER_H + 42
LABEL_W    = 60

for i, (name, color, ratio) in enumerate(SUBJECTS):
    y = START_Y + i * (BAR_H + BAR_GAP)

    # 科目標籤色塊
    dot_x = BAR_X0
    draw.rounded_rectangle([dot_x, y + 6, dot_x + LABEL_W - 8, y + BAR_H - 6],
                            radius=10, fill=(*color, 220))

    # 底軌（灰）
    track_x0 = BAR_X0 + LABEL_W
    track_x1 = BAR_X0 + LABEL_W + BAR_MAX_W
    draw.rounded_rectangle([track_x0, y, track_x1, y + BAR_H],
                            radius=BAR_H // 2, fill=(200, 210, 230, 160))

    # 進度條
    fill_x1 = track_x0 + int(BAR_MAX_W * ratio)
    if fill_x1 > track_x0 + BAR_H:
        draw.rounded_rectangle([track_x0, y, fill_x1, y + BAR_H],
                                radius=BAR_H // 2, fill=(*color, 240))

    # 亮點（光澤感）
    draw.rounded_rectangle([track_x0 + 6, y + 6, fill_x1 - 6, y + BAR_H // 2 - 2],
                            radius=6, fill=(255, 255, 255, 55))

    # 百分比小圓標
    pct = int(ratio * 100)
    pct_r = 26
    pct_cx = fill_x1 + pct_r + 6
    pct_cy = y + BAR_H // 2
    draw.ellipse([pct_cx - pct_r, pct_cy - pct_r, pct_cx + pct_r, pct_cy + pct_r],
                 fill=(*color, 255))

# ── 7. 放大鏡（右下角，代表 AI 分析）────────────────────────────
MG_CX, MG_CY = 762, 750
MG_R_OUTER   = 98
MG_R_INNER   = 78
HANDLE_LEN   = 90
HANDLE_W     = 28
HANDLE_ANGLE = math.radians(45)

# 手柄
hx1 = int(MG_CX + (MG_R_OUTER - 8) * math.cos(HANDLE_ANGLE))
hy1 = int(MG_CY + (MG_R_OUTER - 8) * math.sin(HANDLE_ANGLE))
hx2 = int(hx1 + HANDLE_LEN * math.cos(HANDLE_ANGLE))
hy2 = int(hy1 + HANDLE_LEN * math.sin(HANDLE_ANGLE))
draw.line([(hx1, hy1), (hx2, hy2)],
          fill=(24, 62, 148, 255), width=HANDLE_W)
draw.ellipse([hx2 - HANDLE_W // 2, hy2 - HANDLE_W // 2,
              hx2 + HANDLE_W // 2, hy2 + HANDLE_W // 2],
             fill=(24, 62, 148, 255))

# 外框
draw.ellipse([MG_CX - MG_R_OUTER, MG_CY - MG_R_OUTER,
              MG_CX + MG_R_OUTER, MG_CY + MG_R_OUTER],
             fill=(24, 62, 148, 255))
# 鏡片（半透明白）
draw.ellipse([MG_CX - MG_R_INNER, MG_CY - MG_R_INNER,
              MG_CX + MG_R_INNER, MG_CY + MG_R_INNER],
             fill=(220, 235, 255, 210))
# 鏡片光澤
draw.ellipse([MG_CX - MG_R_INNER + 8, MG_CY - MG_R_INNER + 8,
              MG_CX - 18,               MG_CY - 18],
             fill=(255, 255, 255, 100))

# 鏡片內迷你折線圖（代表分析/趨勢）
pts = [(MG_CX - 46, MG_CY + 22),
       (MG_CX - 22, MG_CY - 8),
       (MG_CX + 4,  MG_CY + 10),
       (MG_CX + 30, MG_CY - 28),
       (MG_CX + 46, MG_CY - 14)]
for j in range(len(pts) - 1):
    draw.line([pts[j], pts[j + 1]], fill=(24, 62, 148, 200), width=7)
for px, py in pts:
    draw.ellipse([px - 5, py - 5, px + 5, py + 5],
                 fill=(24, 62, 148, 230))

# ── 8. 儲存 ──────────────────────────────────────────────────────
out_path = "/Users/john/Desktop/Code/Exam/Exam/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
img_rgb = img.convert("RGB")  # iOS 不支援 RGBA icon
img_rgb.save(out_path, "PNG", dpi=(72, 72))
print(f"Saved: {out_path}  ({SIZE}×{SIZE})")

# 預覽用小圖
prev = img_rgb.resize((256, 256), Image.LANCZOS)
prev.save("/Users/john/Desktop/Code/Exam/icon_preview_256.png")
print("Preview: /Users/john/Desktop/Code/Exam/icon_preview_256.png")
