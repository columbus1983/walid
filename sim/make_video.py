"""Simulation video du robot : idle -> ecoute -> reflexion -> parole -> idle.
Reproduit la logique d'animation du firmware (firmware/src/main.cpp, drawEyes).
Aucun son. Usage : python3 sim/make_video.py sim/robot_sim.mp4
"""
import math, subprocess, sys, random
from PIL import Image, ImageDraw, ImageFont

W, H, FPS, S = 720, 760, 30, 2          # S = sur-echantillonnage
OUT = sys.argv[1] if len(sys.argv) > 1 else "sim/robot_sim.mp4"
EYE = (190, 220, 255)
BG = (238, 240, 232)
BODY, BODY_D = (150, 172, 70), (120, 142, 52)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

# (debut, fin, etat, legende, texte)
TIMELINE = [
    (0.0, 3.0, "idle", "Au repos", ""),
    (3.0, 6.0, "listening", "Je t'ecoute...", "Toi : \"Bonjour Shiko, tu peux m'aider ?\""),
    (6.0, 8.5, "thinking", "Je reflechis...", "STT -> Claude -> TTS"),
    (8.5, 14.0, "speaking", "Je reponds", "Shiko : \"Bien sur ! Dis-moi ce dont tu as besoin.\""),
    (14.0, 17.0, "idle", "Au repos", ""),
]
DUR = TIMELINE[-1][1]
random.seed(3)
blinks = [1.2, 2.4, 15.0, 16.2]

def state_at(t):
    for a, b, st, cap, txt in TIMELINE:
        if a <= t < b:
            return st, cap, txt, t - a
    return "idle", "", "", 0

def font(sz, bold=False):
    return ImageFont.truetype(FB if bold else FONT, sz * S)

def frame(t):
    st, cap, txt, lt = state_at(t)
    im = Image.new("RGB", (W * S, H * S), BG)
    d = ImageDraw.Draw(im)
    s = lambda v: int(v * S)

    # corps du robot (vue de face) + ombre
    d.rounded_rectangle([s(120), s(60), s(600), s(520)], s(48), fill=(215, 218, 205))
    d.rounded_rectangle([s(110), s(40), s(590), s(500)], s(48), fill=BODY)
    d.rounded_rectangle([s(110), s(40), s(590), s(500)], s(48), outline=BODY_D, width=s(4))
    # ecran
    d.rounded_rectangle([s(170), s(100), s(530), s(460)], s(22), fill=(12, 12, 14))
    # trou micro
    d.ellipse([s(344), s(478), s(356), s(490)], fill=BODY_D)

    # yeux (meme logique que drawEyes du firmware, echelle 360/240 = 1.5)
    w, h, dx, dy = 56, 84, 0, 0
    if st == "listening": w, h = 62, 96
    elif st == "thinking": w, h, dx, dy = 50, 70, 12, -14
    elif st == "speaking": h = 84 + 10 * math.sin(t * 1000 / 90.0)
    blink = any(0 <= t - b < 0.14 for b in blinks) and st == "idle"
    if blink: h = 8
    k = 1.5
    cx0, cy0 = 350, 280          # centre ecran
    for ex in (-45, 45):         # +-45 px (240 px ecran: 75 / 165 -> +-45)
        cx = cx0 + (ex + dx) * k
        cy = cy0 + (dy - 0) * k
        d.ellipse([s(cx - w * k / 2), s(cy - h * k / 2), s(cx + w * k / 2), s(cy + h * k / 2)], fill=EYE)
    if st == "thinking":
        d.text((s(480), s(120)), "?", font=font(52, True), fill=(255, 255, 255))
    # barre d'etat de l'ecran
    d.text((s(185), s(108)), "12:30", font=font(14), fill=(150, 150, 150))
    d.text((s(470), s(108)), "wifi", font=font(14), fill=(150, 150, 150))

    # indicateur micro / onde sonore
    if st == "listening":
        for i in range(21):
            hh = 6 + 26 * abs(math.sin(t * 9 + i * 0.7)) * (0.4 + 0.6 * math.sin(i / 20 * math.pi))
            x = 250 + i * 10
            d.rounded_rectangle([s(x), s(556 - hh), s(x + 6), s(556 + hh)], s(3), fill=(214, 74, 74))
    if st == "speaking":
        for i in range(21):
            hh = 6 + 22 * abs(math.sin(t * 7 + i * 0.5)) * (0.4 + 0.6 * math.sin(i / 20 * math.pi))
            x = 250 + i * 10
            d.rounded_rectangle([s(x), s(556 - hh), s(x + 6), s(556 + hh)], s(3), fill=(70, 130, 200))

    # legende
    d.text((s(W / 2), s(630)), cap, font=font(30, True), fill=(40, 40, 40), anchor="mm")
    if txt:
        d.text((s(W / 2), s(680)), txt, font=font(20), fill=(70, 70, 70), anchor="mm")
    d.text((s(W / 2), s(735)), "Simulation (sans son) - animation reprise du firmware", font=font(14), fill=(140, 140, 140), anchor="mm")
    return im.resize((W, H), Image.LANCZOS)

ff = subprocess.Popen(
    ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24",
     "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264",
     "-pix_fmt", "yuv420p", "-crf", "20", OUT], stdin=subprocess.PIPE)
for n in range(int(DUR * FPS)):
    ff.stdin.write(frame(n / FPS).tobytes())
ff.stdin.close()
ff.wait()
print("ecrit", OUT)
