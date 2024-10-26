# The Pow-XOR Confusion Problem

I stumbled upon a weird problem recently. This repository documents my initial approach at tackling the problem.

It's entirely possible that I am missing something super basic and this is actually a really easy problem. I'm starting to get that feeling as I go further a long, but that's the math life, I guess :)

## Definition of $X_n$

Let $n \in \mathbb{Z}$, $n \geq 0$.

$X_n$ is the set of solutions $(a, b) \in \mathbb{Z} \times \mathbb{Z}$ to the equation $a^b \equiv a \oplus b \pmod{n}$ for $0 \leq a,b < 2^n$, where $\oplus$ denotes the XOR operation.

# Solution

I am in the process of working on a solution. [Here's what I've done so far](https://raw.githubusercontent.com/SnootierMoon/The-Pow-XOR-Confusion-Problem/doc/pow_xor_confuse.pdf).

A partial solution can be found in `do_math.py`.
