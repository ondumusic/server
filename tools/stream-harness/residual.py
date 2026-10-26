# Sub-millisecond view of a captured or decoded 440Hz tone: fits the ideal sine on a
# steady stretch and prints the largest residual in each 1ms window around the join,
# against the residual elsewhere. Usage: residual.py file.wav [join_ms]
import math, struct, sys, wave
w = wave.open(sys.argv[1]); rate = w.getframerate(); n = w.getnframes()
x = [v / 32768.0 for v in struct.unpack(f'<{n}h', w.readframes(n))]
w1 = rate // 1000
peaks = [max(abs(v) for v in x[i:i+w1]) for i in range(0, n - w1, w1)]
loud = [i for i, p in enumerate(peaks) if p > 0.3 * max(peaks)]
start, end = loud[0], loud[-1]
join = int(sys.argv[2]) if len(sys.argv) > 2 else (start + end) // 2
def fit(a, b):  # least squares sine at exactly 440Hz over samples a..b
    sc = ss = cc = cs = 0.0
    for i in range(a, b):
        t = 2 * math.pi * 440 * i / rate; c, s = math.cos(t), math.sin(t)
        sc += x[i] * c; ss += x[i] * s; cc += c * c; cs += s * s
    return sc / cc, ss / cs
def residual(a, b, A, B):
    return max(abs(x[i] - A * math.cos(2 * math.pi * 440 * i / rate) - B * math.sin(2 * math.pi * 440 * i / rate)) for i in range(a, b))
before = fit((join - 1500) * w1, (join - 500) * w1)
after = fit((join + 500) * w1, (join + 1500) * w1)
amp = math.hypot(*before)
floor_b = residual((join - 1500) * w1, (join - 500) * w1, *before)
floor_a = residual((join + 500) * w1, (join + 1500) * w1, *after)
# a phase change between the two fits is a time shift at the join
shift = (math.atan2(before[1], before[0]) - math.atan2(after[1], after[0])) / (2 * math.pi * 440) * 1000
shift = (shift + 1000 / 440 / 2) % (1000 / 440) - 1000 / 440 / 2
print(f"amplitude {amp:.4f}, residual floor before/after join {floor_b/amp:.4f}/{floor_a/amp:.4f} of amplitude, phase shift across join {shift:+.3f} ms")
worst = []
for ms in range(join - 30, join + 31):
    A, B = before if ms < join else after
    r = residual(ms * w1, (ms + 1) * w1, A, B) / amp
    worst.append((r, ms))
worst.sort(reverse=True)
print("  worst 1ms windows within ±30ms of the join (residual / amplitude): " + ", ".join(f"{ms}ms {r:.3f}" for r, ms in worst[:5]))
