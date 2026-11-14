"""يولّد مؤثرات صوتية بسيطة (WAV) في assets/sounds. شغّله: python3 tool/gen_sounds.py"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sounds')
os.makedirs(OUT, exist_ok=True)
random.seed(4)

def write(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    data = b''.join(struct.pack('<h', int(max(-1, min(1, s / peak * 0.85)) * 32767)) for s in samples)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

def env(i, n, attack=0.005, power=3.0):
    t = i / n
    a = min(1.0, i / (SR * attack))
    return a * (1 - t) ** power

def tone(freq, dur, power=3.0, harm=(1.0, 0.3, 0.1)):
    n = int(SR * dur)
    return [env(i, n, power=power) * sum(h * math.sin(2 * math.pi * freq * (k + 1) * i / SR) for k, h in enumerate(harm)) for i in range(n)]

def noise(dur, power=6.0, lp=0.35):
    n = int(SR * dur); y = 0.0; out = []
    for i in range(n):
        y += lp * (random.uniform(-1, 1) - y)
        out.append(env(i, n, 0.001, power) * y)
    return out

def mix(*tracks):
    n = max(len(t) for t in tracks)
    return [sum(t[i] for t in tracks if i < len(t)) for i in range(n)]

def seq(parts, gap=0.0):
    out = []
    for p in parts:
        out += p + [0.0] * int(SR * gap)
    return out

def delay(track, sec):
    return [0.0] * int(SR * sec) + track

write('card', mix(noise(0.09, 5, 0.5), [s * 0.6 for s in tone(140, 0.07, 6, (1,))]))
write('deal', mix(*[delay(noise(0.05, 5, 0.6), 0.09 * k) for k in range(5)]))
write('bid', tone(660, 0.12, 4))
write('click', tone(900, 0.04, 5, (1,)))
write('tick', tone(1200, 0.03, 4, (1,)))
write('turn', seq([tone(784, 0.12, 3), tone(1047, 0.22, 3)]))
write('trick', mix(noise(0.18, 3, 0.2), [s * 0.5 for s in tone(220, 0.15, 3)]))
write('win', seq([tone(f, 0.16, 2) for f in (523, 659, 784, 1047)], 0.01))
write('lose', seq([tone(f, 0.22, 2) for f in (392, 349, 311, 262)], 0.01))
print('done')
