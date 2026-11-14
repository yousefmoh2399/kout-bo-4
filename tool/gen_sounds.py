"""
مولّد المؤثرات الصوتية الاحترافية للعبة كوت بو ٤ (WAV 44.1kHz 16-bit).
يولّد أصواتاً طبيعية ودافئة باستخدام التوليف الصوتي الفيزيائي والموسيقي:
- النقر التكتيكي (Click)
- رمي الورق وسحب اللمة وتوزيع الورق (Card Snap, Deal Riffle, Trick Sweep)
- رنين المزايدة وتنبيه الدور (Luxury Chime, Turn Alert)
- دقات المؤقت الخشبية (Woodblock Tick)
- نغمة الفوز السينمائية ونغمة الخسارة الهادئة (Win Fanfare, Defeat Cadence)
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
os.makedirs(OUT, exist_ok=True)
random.seed(42)

def clamp(val, low=-1.0, high=1.0):
    return max(low, min(high, val))

def write_wav(name, samples, stereo=False):
    peak = max(1e-9, max(abs(s) for s in samples))
    # Normalize with headroom
    target_peak = 0.88
    scale = target_peak / peak if peak > target_peak else 1.0

    if stereo:
        frames = bytearray()
        for i in range(0, len(samples), 2):
            l = int(clamp(samples[i] * scale) * 32767)
            r = int(clamp(samples[i + 1] * scale) * 32767)
            frames.extend(struct.pack('<hh', l, r))
        with wave.open(os.path.join(OUT, f'{name}.wav'), 'wb') as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(frames)
    else:
        frames = bytearray()
        for s in samples:
            val = int(clamp(s * scale) * 32767)
            frames.extend(struct.pack('<h', val))
        with wave.open(os.path.join(OUT, f'{name}.wav'), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(frames)

def adsr(i, total, a=0.005, d=0.05, s=0.7, r=0.2, p=2.0):
    t = i / total
    at_samp = max(1, int(a * SR))
    if i < at_samp:
        return (i / at_samp) ** 1.2
    dt_samp = max(1, int(d * SR))
    if i < at_samp + dt_samp:
        f = (i - at_samp) / dt_samp
        return 1.0 - (1.0 - s) * (f ** p)
    rt_samp = max(1, int(r * SR))
    if i > total - rt_samp:
        f = (total - i) / rt_samp
        return s * (f ** p)
    return s

def exp_decay(i, total, power=3.0):
    t = i / total
    # Smooth attack (first 2ms)
    att = min(1.0, i / (SR * 0.002))
    return att * (math.exp(-power * t) - math.exp(-power)) / (1.0 - math.exp(-power) + 1e-6)

def lowpass_noise(dur, cutoff=0.3, power=5.0):
    n = int(dur * SR)
    out = []
    y = 0.0
    for i in range(n):
        y += cutoff * (random.uniform(-1.0, 1.0) - y)
        env = exp_decay(i, n, power)
        out.append(y * env)
    return out

def bandpass_noise(dur, center_freq=1200, q=6.0, power=6.0):
    n = int(dur * SR)
    bw = center_freq / q
    r = math.exp(-math.pi * bw / SR)
    c = 2 * r * math.cos(2 * math.pi * center_freq / SR)
    r2 = r * r
    y1 = 0.0
    y2 = 0.0
    out = []
    for i in range(n):
        white = random.uniform(-1.0, 1.0)
        y = (1 - r) * white + c * y1 - r2 * y2
        y2 = y1
        y1 = y
        env = exp_decay(i, n, power)
        out.append(y * env)
    return out

def bell_tone(freq, dur, harmonics=((1.0, 1.0), (2.0, 0.4), (3.0, 0.2), (4.2, 0.1)), power=3.5):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = exp_decay(i, n, power)
        sample = sum(h_amp * math.sin(2 * math.pi * freq * h_mul * t) for h_mul, h_amp in harmonics)
        out[i] = sample * env
    return out

def marimba_tone(freq, dur, power=5.0):
    n = int(dur * SR)
    out = [0.0] * n
    for i in range(n):
        t = i / SR
        env = exp_decay(i, n, power)
        s = (
            math.sin(2 * math.pi * freq * t) * 1.0
            + math.sin(2 * math.pi * freq * 3.0 * t) * 0.25 * exp_decay(i, n, power * 2.0)
            + math.sin(2 * math.pi * freq * 9.2 * t) * 0.08 * exp_decay(i, n, power * 4.0)
        )
        out[i] = s * env
    return out

def mix(*tracks):
    length = max(len(t) for t in tracks)
    res = [0.0] * length
    for t in tracks:
        for i, val in enumerate(t):
            res[i] += val
    return res

def pad_delay(track, delay_sec):
    delay_samps = int(delay_sec * SR)
    return [0.0] * delay_samps + track

def generate_click():
    # Tactile luxury UI click: crisp low thump + subtle high resonant wood click
    thump = bell_tone(220, 0.025, harmonics=((1.0, 1.0), (1.5, 0.3)), power=8.0)
    tick = bandpass_noise(0.015, center_freq=2400, q=4.0, power=9.0)
    return mix(thump, [s * 0.45 for s in tick])

def generate_card():
    # Realistic card slap on felt: air whoosh transient + snappy card slap
    whoosh = lowpass_noise(0.04, cutoff=0.5, power=6.0)
    snap = bandpass_noise(0.06, center_freq=1800, q=2.5, power=7.0)
    body = bell_tone(160, 0.05, harmonics=((1.0, 1.0), (2.2, 0.3)), power=8.0)
    return mix(whoosh, [s * 0.8 for s in snap], [s * 0.5 for s in body])

def generate_deal():
    # Riffle / dealing 5 cards quickly
    snaps = []
    for k in range(5):
        pitch_mod = 1.0 + (k - 2) * 0.05
        single = bandpass_noise(0.045, center_freq=int(1900 * pitch_mod), q=3.0, power=7.0)
        whoosh = lowpass_noise(0.035, cutoff=0.45, power=6.5)
        combined = mix(single, [w * 0.6 for w in whoosh])
        snaps.append(pad_delay(combined, k * 0.065))
    return mix(*snaps)

def generate_bid():
    # Warm casino token / brass bell chime (E5 + B5 + E6)
    tone1 = bell_tone(659.25, 0.28, harmonics=((1.0, 0.9), (2.0, 0.35), (3.0, 0.1)), power=3.5)
    tone2 = bell_tone(987.77, 0.22, harmonics=((1.0, 0.5), (2.0, 0.15)), power=4.0)
    chime = mix(tone1, pad_delay([s * 0.65 for s in tone2], 0.01))
    return chime

def generate_turn():
    # Elegant double notification chime: A5 (880Hz) -> D6 (1174.66Hz)
    n1 = marimba_tone(880.0, 0.22, power=3.8)
    n2 = marimba_tone(1174.66, 0.35, power=3.2)
    bell2 = bell_tone(1174.66, 0.35, harmonics=((1.0, 0.5), (2.0, 0.2)), power=3.0)
    second_part = mix(n2, [s * 0.4 for s in bell2])
    return mix(n1, pad_delay(second_part, 0.09))

def generate_tick():
    # Acoustic woodblock metronome tick
    tok = bell_tone(1150, 0.022, harmonics=((1.0, 1.0), (2.1, 0.25)), power=10.0)
    tap = bandpass_noise(0.014, center_freq=3200, q=5.0, power=11.0)
    return mix(tok, [s * 0.4 for s in tap])

def generate_trick():
    # Card sweep and collect: card slide friction + soft thump
    slide = lowpass_noise(0.16, cutoff=0.35, power=3.5)
    slide2 = bandpass_noise(0.12, center_freq=1400, q=2.0, power=4.5)
    thump = bell_tone(180, 0.09, harmonics=((1.0, 1.0), (1.8, 0.4)), power=6.5)
    return mix([s * 0.7 for s in slide], [s * 0.5 for s in slide2], pad_delay(thump, 0.04))

def generate_win():
    # Glorious triumphant celebratory arpeggio: C5 -> E5 -> G5 -> C6 -> E6
    notes = [
        (523.25, 0.35, 0.00), # C5
        (659.25, 0.35, 0.09), # E5
        (783.99, 0.40, 0.18), # G5
        (1046.50, 0.55, 0.28), # C6
        (1318.51, 0.65, 0.38), # E6
    ]
    parts = []
    for freq, dur, start in notes:
        m = marimba_tone(freq, dur, power=2.8)
        b = bell_tone(freq, dur, harmonics=((1.0, 0.7), (2.0, 0.35), (3.0, 0.15)), power=2.5)
        combined = mix(m, [s * 0.6 for s in b])
        parts.append(pad_delay(combined, start))
    return mix(*parts)

def generate_lose():
    # Respectful, warm melancholic descending cadence: E4 -> D4 -> C4 -> A3
    notes = [
        (329.63, 0.28, 0.00), # E4
        (293.66, 0.28, 0.12), # D4
        (261.63, 0.32, 0.24), # C4
        (220.00, 0.50, 0.38), # A3
    ]
    parts = []
    for freq, dur, start in notes:
        m = marimba_tone(freq, dur, power=3.2)
        b = bell_tone(freq, dur, harmonics=((1.0, 0.5), (2.0, 0.2)), power=3.0)
        combined = mix(m, [s * 0.45 for s in b])
        parts.append(pad_delay(combined, start))
    return mix(*parts)

def main():
    print("Generating professional sound effects (44.1kHz)...")
    write_wav('click', generate_click())
    write_wav('card', generate_card())
    write_wav('deal', generate_deal())
    write_wav('bid', generate_bid())
    write_wav('turn', generate_turn())
    write_wav('tick', generate_tick())
    write_wav('trick', generate_trick())
    write_wav('win', generate_win())
    write_wav('lose', generate_lose())
    print("All professional sounds generated successfully!")

if __name__ == '__main__':
    main()
