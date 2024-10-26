import argparse

def ctz(n):
    return (n & -n).bit_length() - 1

def order_of_a_mod_2n(a, n):
    x = a
    k = 1
    while x != 1:
        x = (x * x) % n
        k <<= 1
    return k

def fast_exp(a, b, n):
    ret = 1
    apow = a
    for bit in f"{b:b}"[::-1]:
        if int(bit) == 1:
            ret = (ret * apow) % n
        apow = (apow * apow) % n
    return ret

def solve_for_a(b, n):
    if b == 0:
        if n == 1:
            return [0]
        else:
            return []
    elif b % 1:
        return []
    else:
        raise Exception("TODO")

def solve_for_b(a, n):
    if n == 1:
        return [0]
    elif a % 2:
        k = order_of_a_mod_2n(a, n)
        b = solve_for_b(a % k, k)[0]
        return [a ^ fast_exp(a, b, n)]
    else:
        l = []
        if fast_exp(a, a, n) == 0:
            l.append(a)
        apow = 1
        for b in range(0, ctz(n), 2):
            if apow == a ^ b:
                l.append(b)
            apow = (a * a * apow) % n
        return l
                

def solve_for_n(a, b):
    if b % 1:
        return []
    else:
        raise Exception("TODO: a and b")


def solve_for_ab(n):
    return [(a, b) for a in range(n) for b in solve_for_b(a, n)]

def solve_for_an(b):
    raise Exception("TODO: only b")

def solve_for_bn(a):
    raise Exception("TODO: only a")

def run(a=None, b=None, n=None):
    
    if a != None and b != None and n != None:
        if fast_exp(a, b, n) != a ^ b:
            return []
        else:
            return [(a, b, n)]
    elif a != None and b != None:
        return [(a, b, n) for n in solve_for_n(a, b)]
    elif a != None and n != None:
        return [(a, b, n) for b in solve_for_b(a, n)]
    elif b != None and n != None:
        return [(a, b, n) for a in solve_for_a(b, n)]
    elif a != None:
        return [(a, b, n) for (b, n) in solve_for_bn(a)]
    elif b != None:
        return [(a, b, n) for (a, n) in solve_for_an(b)]
    elif n != None:
        return [(a, b, n) for (a, b) in solve_for_ab(n)]

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Find all solutions to `a XOR b = a POW b  (MOD n)`.")
    parser.add_argument("-a", type=int, help="base/LHS of XOR", required=False)
    parser.add_argument("-b", type=int, help="exponent/RHS of XOR", required=False)
    parser.add_argument("-n", type=int, help="modulus", required=False)

    args = parser.parse_args()
    a, b, n = args.a, args.b, args.n
    if a == None and b == None and n == None:
        parser.error("at least one of '-a', '-b', '-n', must be specified")
    if n != None:
        if not (n >= 0 and n.bit_count() == 1):
            parser.error(f"argument 'n': must be power of 2, got {n}")
        if a != None and not (0 <= a < n):
            parser.error(f"argument 'a': must be in [0, n), got a={a}, n={n}")
        if b != None and not (0 <= b < n):
            parser.error(f"argument 'b': must be in [0, n), got b={b}, n={n}")

    l = run(a=a, b=b, n=n)
    az, bz, nz = 0, 0, 0
    for a, b, n in l:
        az, bz, nz = max(az, len(str(a))), max(bz, len(str(b))), max(nz, len(str(n)))
    print(f"| {'a':<{az}} | {'b':<{bz}} | {'n':<{nz}} |")
    print(f"|-{'-':<{az}}-|-{'-':<{bz}}-|-{'-':<{nz}}-|")
    for a, b, n in l:
        print(f"| {a:<{az}} | {b:<{bz}} | {n:<{nz}} |")

