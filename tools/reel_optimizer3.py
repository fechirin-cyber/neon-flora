"""
Reel Optimizer v3: LEFT reel with 3-consecutive S7R (instead of 3-BEL)
Zero cross-alignment across all 5 lines, BEL gap<=5, RPL gap<=5
"""
import random
import itertools

# Symbol IDs (matching reel_data.gd)
S7R, S7B, BAR, CHR, BEL, ICE, RPL = 0, 1, 2, 3, 4, 5, 6
REEL_SIZE = 21

# Symbol counts per reel
# LEFT: S7R x3 (was x1), BEL x7 (was x9), rest same
LEFT_COUNTS = {CHR: 2, S7R: 3, S7B: 1, BAR: 1, BEL: 7, ICE: 2, RPL: 5}
CENTER_COUNTS = {S7R: 1, S7B: 1, BAR: 1, BEL: 9, ICE: 3, RPL: 6}
RIGHT_COUNTS = {S7R: 1, S7B: 1, BAR: 1, BEL: 9, ICE: 3, RPL: 6}

# 5 paylines: (row_L, row_C, row_R) where 0=top, 1=mid, 2=bot
LINES = [(0,0,0), (1,1,1), (2,2,2), (0,1,2), (2,1,0)]

# Winning symbols (3-of-a-kind pays out)
WIN_SYMS = [S7R, S7B, BAR, CHR, BEL, ICE, RPL]

def counts_to_pool(counts):
    pool = []
    for sym, n in counts.items():
        pool.extend([sym] * n)
    assert len(pool) == REEL_SIZE
    return pool

def max_gap(reel, sym):
    positions = [i for i, s in enumerate(reel) if s == sym]
    if len(positions) <= 1:
        return REEL_SIZE
    mg = 0
    for i in range(len(positions)):
        nxt = positions[(i + 1) % len(positions)]
        cur = positions[i]
        gap = (nxt - cur) % REEL_SIZE
        mg = max(mg, gap)
    return mg

def has_triple(reel, sym):
    """Check if reel has 3 consecutive occurrences of sym"""
    for i in range(REEL_SIZE):
        if (reel[i] == sym and
            reel[(i+1) % REEL_SIZE] == sym and
            reel[(i+2) % REEL_SIZE] == sym):
            return True
    return False

def get_window(reel, center_pos):
    return [
        reel[(center_pos - 1) % REEL_SIZE],
        reel[center_pos % REEL_SIZE],
        reel[(center_pos + 1) % REEL_SIZE],
    ]

def count_cross_alignments(left, center, right):
    """Count how many 3-reel window combos have multiple symbols winning on different lines"""
    total = 0
    for lp in range(REEL_SIZE):
        lw = get_window(left, lp)
        for cp in range(REEL_SIZE):
            cw = get_window(center, cp)
            for rp in range(REEL_SIZE):
                rw = get_window(right, rp)
                wins = 0
                for line in LINES:
                    s = lw[line[0]]
                    if s == cw[line[1]] == rw[line[2]] and s in WIN_SYMS:
                        wins += 1
                if wins >= 2:
                    total += 1
    return total

def validate_reel(reel, counts, require_s7r_triple=False):
    """Check basic constraints"""
    # Verify counts
    for sym, n in counts.items():
        if reel.count(sym) != n:
            return False
    # BEL gap
    if BEL in counts and counts[BEL] > 0:
        if max_gap(reel, BEL) > 5:
            return False
    # RPL gap
    if RPL in counts and counts[RPL] > 0:
        if max_gap(reel, RPL) > 5:
            return False
    # S7R triple
    if require_s7r_triple:
        if not has_triple(reel, S7R):
            return False
    return True

def generate_valid_reel(counts, require_s7r_triple=False, max_attempts=50000):
    pool = counts_to_pool(counts)
    for _ in range(max_attempts):
        reel = pool[:]
        random.shuffle(reel)
        if require_s7r_triple:
            # Force 3-S7R at random position
            s7r_positions = [i for i, s in enumerate(reel) if s == S7R]
            non_s7r = [s for s in reel if s != S7R]
            random.shuffle(non_s7r)
            # Pick random start for triple
            start = random.randint(0, REEL_SIZE - 1)
            reel2 = [None] * REEL_SIZE
            reel2[start] = S7R
            reel2[(start + 1) % REEL_SIZE] = S7R
            reel2[(start + 2) % REEL_SIZE] = S7R
            idx = 0
            for i in range(REEL_SIZE):
                if reel2[i] is None:
                    reel2[i] = non_s7r[idx]
                    idx += 1
            reel = reel2
        if validate_reel(reel, counts, require_s7r_triple):
            return reel
    return None

def swap_random(reel):
    """Swap two random positions (different symbols)"""
    r = reel[:]
    attempts = 0
    while attempts < 50:
        i, j = random.sample(range(REEL_SIZE), 2)
        if r[i] != r[j]:
            r[i], r[j] = r[j], r[i]
            return r
        attempts += 1
    return r

def main():
    print("=== Reel Optimizer v3: 3-S7R on LEFT ===")
    print(f"LEFT counts: S7R=3, S7B=1, BAR=1, CHR=2, BEL=7, ICE=2, RPL=5")
    print(f"CENTER/RIGHT counts: S7R=1, S7B=1, BAR=1, BEL=9, ICE=3, RPL=6")
    print()

    best_score = 999999
    best_reels = None

    # Phase 1: Random search
    print("Phase 1: Random search (10000 iterations)...")
    for iteration in range(10000):
        left = generate_valid_reel(LEFT_COUNTS, require_s7r_triple=True)
        center = generate_valid_reel(CENTER_COUNTS)
        right = generate_valid_reel(RIGHT_COUNTS)
        if left is None or center is None or right is None:
            continue
        score = count_cross_alignments(left, center, right)
        if score < best_score:
            best_score = score
            best_reels = (left[:], center[:], right[:])
            print(f"  iter {iteration}: cross_align={score}")
            if score == 0:
                break

    if best_reels is None:
        print("ERROR: Could not generate valid reels")
        return

    print(f"\nPhase 1 best: {best_score}")

    if best_score > 0:
        # Phase 2: Simulated annealing
        print(f"\nPhase 2: Simulated annealing (100000 iterations)...")
        left, center, right = best_reels
        temp = 5.0
        for iteration in range(100000):
            # Pick random reel to modify
            which = random.randint(0, 2)
            if which == 0:
                candidate = swap_random(left)
                if not validate_reel(candidate, LEFT_COUNTS, require_s7r_triple=True):
                    continue
                new_score = count_cross_alignments(candidate, center, right)
                delta = new_score - best_score
                if delta <= 0 or random.random() < 2.718 ** (-delta / temp):
                    left = candidate
                    if new_score < best_score:
                        best_score = new_score
                        best_reels = (left[:], center[:], right[:])
                        print(f"  iter {iteration}: cross_align={new_score}")
            elif which == 1:
                candidate = swap_random(center)
                if not validate_reel(candidate, CENTER_COUNTS):
                    continue
                new_score = count_cross_alignments(left, candidate, right)
                delta = new_score - best_score
                if delta <= 0 or random.random() < 2.718 ** (-delta / temp):
                    center = candidate
                    if new_score < best_score:
                        best_score = new_score
                        best_reels = (left[:], center[:], right[:])
                        print(f"  iter {iteration}: cross_align={new_score}")
            else:
                candidate = swap_random(right)
                if not validate_reel(candidate, RIGHT_COUNTS):
                    continue
                new_score = count_cross_alignments(left, center, candidate)
                delta = new_score - best_score
                if delta <= 0 or random.random() < 2.718 ** (-delta / temp):
                    right = candidate
                    if new_score < best_score:
                        best_score = new_score
                        best_reels = (left[:], center[:], right[:])
                        print(f"  iter {iteration}: cross_align={new_score}")

            temp *= 0.99997
            if best_score == 0:
                break

    print(f"\n=== RESULT: cross_alignments = {best_score} ===")

    if best_reels:
        left, center, right = best_reels
        SYM_NAMES = {S7R: "S7R", S7B: "S7B", BAR: "BAR", CHR: "CHR", BEL: "BEL", ICE: "ICE", RPL: "RPL"}

        print(f"\nLEFT:   {[SYM_NAMES[s] for s in left]}")
        print(f"CENTER: {[SYM_NAMES[s] for s in center]}")
        print(f"RIGHT:  {[SYM_NAMES[s] for s in right]}")

        # Verify constraints
        print(f"\nConstraint check:")
        print(f"  LEFT  - S7R triple: {has_triple(left, S7R)}, BEL gap: {max_gap(left, BEL)}, RPL gap: {max_gap(left, RPL)}")
        print(f"  CENTER - BEL gap: {max_gap(center, BEL)}, RPL gap: {max_gap(center, RPL)}")
        print(f"  RIGHT  - BEL gap: {max_gap(right, BEL)}, RPL gap: {max_gap(right, RPL)}")

        # Print GDScript format
        print(f"\n# GDScript format:")
        def to_gd(reel):
            names = {S7R: "S7R", S7B: "S7B", BAR: "BAR", CHR: "CHR", BEL: "BEL", ICE: "ICE", RPL: "RPL"}
            return ", ".join(names[s] for s in reel)

        print(f"const LEFT: Array[int] = [")
        print(f"\t{to_gd(left[:10])},")
        print(f"\t{to_gd(left[10:])}")
        print(f"]")
        print(f"const CENTER: Array[int] = [")
        print(f"\t{to_gd(center[:10])},")
        print(f"\t{to_gd(center[10:])}")
        print(f"]")
        print(f"const RIGHT: Array[int] = [")
        print(f"\t{to_gd(right[:10])},")
        print(f"\t{to_gd(right[10:])}")
        print(f"]")

if __name__ == "__main__":
    main()
