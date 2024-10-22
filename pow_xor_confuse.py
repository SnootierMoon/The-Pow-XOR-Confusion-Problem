import argparse
import os
import sys

def pow_xor_confuse(n, o=None):
    if not n:
        if o:
            print("a,b", file=o)
            print("0,0", file=o)
        return [(0,0)]
    l = []
    if o:
        print("a,b", file=o)
    for a in range(1 << n):
        prod = 1
        for b in range(0, 1 << n):
            if a ^ b == prod:
                l.append((a, b))
                if o: 
                    print(f"{a},{b}", file=o)
            prod = (prod * a) % (1 << n)

    return l

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Brute force the POW-XOR Confusion problem")
    parser.add_argument('-n', type=int, choices=range(0, 32 + 1), metavar="[0...32]", required=True)
    parser.add_argument('-o', type=str, metavar="file.csv")

    args = parser.parse_args()

    if args.o:
        with open(args.o, "w") as f:
            pow_xor_confuse(args.n, f)
    else:
        pow_xor_confuse(args.n, sys.stdout)
