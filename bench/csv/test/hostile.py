# Writes a CSV where most fields are quoted and hold commas, "" escapes and
# newlines (including the group-by key), plus the `.expected` totals computed
# with Python's csv module as an oracle independent of the Odin readers.
#
#   python3 test/hostile.py <out.csv> <rows> [long]
#
# With "long", every note is a quoted field of many short lines, so a cut at an
# arbitrary byte usually lands inside quotes (exercises v12's wrong guesses).
import csv
import random
import sys

path, rows = sys.argv[1], int(sys.argv[2])
long_notes = len(sys.argv) > 3 and sys.argv[3] == 'long'
rnd = random.Random(7)
cities = ['Oslo', 'A, B', 'Q "x"', 'new\nline', 'Z']
notes = ['\n', ',\n,', '""\n"', 'x\ny\nz', '', 'plain']
agg = {}
with open(path, 'w', newline='') as f:
    w = csv.writer(f, lineterminator='\n')
    w.writerow(['id', 'ts', 'user_id', 'city', 'amount', 'qty', 'note'])
    for i in range(rows):
        c = rnd.choice(cities)
        cents = rnd.randint(-5000, 99999)
        q = rnd.randint(1, 20)
        amt = ('-' if cents < 0 else '') + f'{abs(cents) // 100}.{abs(cents) % 100:02d}'
        note = '\n'.join('l%d, "q"' % j for j in range(rnd.randint(20, 200))) if long_notes else rnd.choice(notes)
        w.writerow([i, '"t\n"', 'u,1', c, amt, q, note])
        a = agg.setdefault(c, [0, 0, 0])
        a[0] += 1
        a[1] += cents
        a[2] += q
with open(path + '.expected', 'w') as f:
    for c in sorted(agg, key=lambda s: s.encode()):
        f.write(f'{c}\t{agg[c][0]}\t{agg[c][1]}\t{agg[c][2]}\n')
