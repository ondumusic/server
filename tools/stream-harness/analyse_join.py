# Looks for an audible discontinuity in a captured 440Hz tone: dips in the 1ms peak
# envelope and irregular zero-crossing intervals (a phase jump or inserted silence).
# Usage: analyse_join.py capture.wav
import struct, sys, wave
w = wave.open(sys.argv[1]); rate = w.getframerate(); n = w.getnframes()
x = [v / 32768.0 for v in struct.unpack(f'<{n}h', w.readframes(n))]
w1 = rate // 1000
peaks = [max(abs(v) for v in x[i:i+w1]) for i in range(0, n - w1, w1)]
loud = [i for i, p in enumerate(peaks) if p > 0.02]
if not loud: print("  no tone captured (is the output muted?)"); sys.exit(1)
start, end = loud[0], loud[-1]
level = sorted(peaks[start:end])[len(peaks[start:end]) // 2]
# the join is around the middle of the tone; the first and last 500ms are start/stop ramps
dips = [i for i, p in enumerate(peaks[start+500:end-500], start+500) if p < level * 0.7]
runs = []
for i in dips:
    if runs and i == runs[-1][1] + 1: runs[-1][1] = i
    else: runs.append([i, i])
seg = x[start * w1: end * w1]
crossings = [i for i in range(1, len(seg)) if seg[i-1] < 0 <= seg[i]]
intervals = [b - a for a, b in zip(crossings, crossings[1:])]
expected = rate / 440
jumps = [(crossings[i] // w1 + start, (iv - expected) / rate * 1000) for i, iv in enumerate(intervals)
         if abs(iv - expected) > 4 and start + 500 <= crossings[i] // w1 + start <= end - 500]
print(f"  tone {start}-{end}ms, peak {level:.3f}; silent stretches: " + (", ".join(f"{a}-{b}ms ({b-a+1}ms)" for a, b in runs) if runs else "none")
      + f"; phase jumps: " + (", ".join(f"{ms}ms ({d:+.2f}ms)" for ms, d in jumps[:6]) if jumps else "none"))
