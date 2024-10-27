import argparse

def lsb(x):
    return x & -x

def ctz(n):
    return lsb(n).bit_length() - 1

def fast_exp(a, b, n):
    ret, apow = 1, a
    for bit in f"{b:b}"[::-1]:
        if int(bit):
            ret = (ret * apow) % (1 << n)
        apow = (apow * apow) % (1 << n) 
    return ret

def gen_seq(b):
    a, n = (lsb(b), ctz(b) + 1)
    while True:
        yield a, n
        n += (b - 1) * ctz(b)
        a = b ^ fast_exp(a, b, n)

# a xor b = a^b

def solve_for_a(b, n):
    if b % 2:
        return
    l = []
    for a_0, n_0 in gen_seq(b):
        if n_0 >= n:
            l.append(a_0 % (1 << n))
            break
    a = 1
    for k in range(1, n+1):
        a = (b ^ fast_exp(a, b, k)) % (1 << k)
    l.append(a)
    yield from sorted(l)

def solve_for_b(a, n):
    if n == 0:
        yield 0
    elif a % 2:
        b = 0
        for k in range(1, n+1):
            b = (a ^ fast_exp(a, b, k)) % (1 << k)
        yield b
    else:
        l = []
        apow = 1
        for b in range(0, n, 2):
            if apow == a ^ b:
                yield b
            apow = (a * a * apow) % (1 << n)
        if a >= n and fast_exp(a, a, n) == 0:
            yield a

def solve_for_n(a, b):
    if b % 2:
        return
    n = 0
    for (a_0, n_0) in gen_seq(b):
        while b < (1 << n_0) and n <= n_0:
            if a == a_0 % (1 << n):
                yield n
            n += 1
    else:
        raise Exception("TODO: a and b")


def solve_for_ab(n):
    yield from ((a, b) for a in range(n) for b in solve_for_b(a, n))

def solve_for_an(b):
    raise Exception("TODO: only b")

def solve_for_bn(a):
    raise Exception("TODO: only a")

def iterate(a=None, b=None, n=None):
    if a != None and b != None and n != None:
        if fast_exp(a, b, n) != a ^ b:
            return
        else:
            yield (a, b, n)
    elif a != None and b != None:
        yield from ((a, b, n) for n in solve_for_n(a, b))
    elif a != None and n != None:
        yield from ((a, b, n) for b in solve_for_b(a, n))
    elif b != None and n != None:
        yield from ((a, b, n) for a in solve_for_a(b, n))
    elif a != None:
        yield from ((a, b, n) for (b, n) in solve_for_bn(a))
    elif b != None:
        yield from ((a, b, n) for (a, n) in solve_for_an(b))
    elif n != None:
        yield from ((a, b, n) for (a, b) in solve_for_ab(n))

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
        if not (n >= 0):
            parser.error(f"argument 'n': must be a nonnegative integer, got {n}")
        if a != None and not (0 <= a < (1<<n)):
            parser.error(f"argument 'a': must be in [0, n), got a={a}, n={n}")
        if b != None and not (0 <= b < (1<<n)):
            parser.error(f"argument 'b': must be in [0, n), got b={b}, n={n}")

    l = iterate(a=a, b=b, n=n)
    print("a,b,n")
    for a, b, n in l:
        print(f"{a},{b},{n}")

