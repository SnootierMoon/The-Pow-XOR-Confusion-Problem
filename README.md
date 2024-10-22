# The Pow-XOR Confusion Problem

I stumbled upon a weird problem recently. This repository documents my initial approach at tackling the problem.

It's entirely possible that I am missing something super basic and this is actually a really easy problem. I'm starting to get that feeling as I go further a long, but that's the math life, I guess :)

## Definition of $X_n$

Let $n \in \mathbb{Z}$, $n \geq 0.$

$X_n$ is the set of solutions $(a, b) \in \mathbb{Z} \times \mathbb{Z}$ to the equation $a^b \equiv a \oplus b \pmod{n}$ for $0 \leq a,b < 2^n$, where $\oplus$ denotes the XOR operation.

The problem is to characterize $X_n$ (enumerate it efficiently).

### Examples

 * For all $n \geq 1$, $1^0 \equiv 1 \pmod{2^n}$ and $1 \oplus 0 = 1$, so $(1, 0) \in X_n$.
 * For all $n \geq 2$, $(n-1)^{n-2} \equiv 1 \pmod{2^n}$ and $(n-1) \oplus (n-2) \equiv 1$, so $(n-1, n-2) \in X_n$.
 * $386969^{47832} \equiv 351553 \pmod{2^{19}}$ and $386969 \oplus 47832 = 351553$, so $(386969, 47832) \in X_{19}$.

### Properties

Some interesting properties of $X_n$ that I discovered:
 * For all $n \geq 1$, $|X_n| = 2^n-1$. Since that $a$ and $b$ come from sets that are of size $2^n$, you would expect there to be some kind of simple frequency rule like "every value of $a$ appears at most once, and one is missing". Such a rule kind-of exists for $b$, but the behavior for frequencies of $a$ seems really strange.
 * For all $n \geq 0$, a value of $b=0$ appears once (with $a=1$), and every other _even_ value of $b$ appears twice.
 * Every value of $a$ appears once, save for the exceptions listed below, which either appear twice or not at all.
 * Also, what's up with 4 popping up out of nowhere in $n=9$ onwards?

| $n$ | values $a$ with no appearances | values $a$ with 2 appearances        |
| --- | ------------------------------ | ------------------------------------ |
| 0   |                                |                                      |
| 1   | 0                              |                                      |
| 2   | 0                              |                                      |
| 3   | 0, 2                           | 6                                    |
| 4   | 0, 2                           | 6                                    |
| 5   | 0, 2                           | 6                                    |
| 6   | 0, 2                           | 38                                   |
| 7   | 0, 2, 6                        | 38, 70                               |
| 8   | 0, 2, 6                        | 70, 166                              |
| 9   | 0, 2, 4, 6                     | 70, 260, 422                         |
| 10  | 0, 2, 4, 6                     | 260, 582, 934                        |
| 11  | 0, 2, 4, 6, 10                 | 260, 1034, 1606, 1958                |
| 12  | 0, 2, 4, 6, 10                 | 260, 1034, 1606, 4006                |
| 13  | 0, 2, 4, 6, 10                 | 260, 1034, 1606, 8102                |
| 14  | 0, 2, 4, 6, 10                 | 260, 1606, 8102, 9226                |
| 15  | 0, 2, 4, 6, 10, 14             | 260, 8102, 16398, 17990, 25610       |
| 16  | 0, 2, 4, 6, 10, 14             | 260, 16398, 40870, 50758, 58378      |
| 17  | 0, 2, 4, 6, 10, 14             | 16398, 50758, 65796, 106406, 123914  |
| 18  | 0, 2, 4, 6, 10, 14             | 16398, 65796, 181830, 237478, 254986 |

#### Proofs

Some of these properties are easy to prove.
 * For all $(a, b) \in X_n$, $b$ is even.
   * Proven by contradiction. Let $(a, b) \in X_n$. Suppose $b$ is odd. If $a$ is even, then $a^b$ is even but $a \oplus b$ is odd. On the other hand, if $a$ is also odd, then $a^b$ is odd but $a \oplus b$ is even. In both cases $a^b \neq a \oplus b$ so $(a, b) \not \in X_n$.
 * For all $(a, b) \in X_n$, if $a$ is even and $b \geq n$, then $a = b$.
   * Let $(a, b) \in X_n$, and suppose $a$ is even and $b \geq n$. Since $a$ is even, we can write $a=2k$ for some $k \in \mathbb{Z}$ and since $b \geq n$, we can write $b = n + m$ for some $m \in \mathbb{Z}$, $m \geq 0$, and so $a^b = (2k)^{n + m} = 2^n (2^mk^{n+m})$, which has $2^n$ as a factor, so therefore $a^b \equiv 0 \pmod{2^n}$. Since $(a, b) \in X_n$, this means $a^b \equiv 0 \equiv a \oplus b \pmod{2^n}$, so $a = b$.
   * This means we only have to iterate $b$ up to $n$ for every $a$ when enumerating solutions.

#### Ideas

For characterizing $X_n$:

 * Look at the $a$ values of the $(a, b)$ pairs that share the same $b$. Since every even positive $b$ appears twice, there might be a relationship between $b$ and its two $a$ values.
 * Investigate why every odd $a$ has a unique $b$. Try to find a mapping.

 * For finding solutions quickly:
   * For even $a$, you only have to iterate up to $n$ to find a $b$. Any other $b$ is equal to $a$ itself.
   * For odd $a$, you need to do a little work to get a good improvement:
     * Euler's Theorem tells us that $a^{\phi(2^n)} \equiv 1 \pmod{2^n}$, and by totient properties $\phi(2^n) = 2^{n-1}$.
     * This means the order of $a \pmod{2^n}$ is a factor of $2^{n-1}$, or in other words is equal to $2^k$ for some $k \in \mathbb{Z}$, $0 \leq k < n$. There are only $n$ options for $k$.
     * A solution $(a, b) \in X_n$ satisfies $a^b \equiv a \oplus b \pmod{2^n}$, which can be rewritten as $a^b \oplus a \equiv b \pmod{2^n}$. The $(k+1)^{th}$ to $n^{th}$ bits of $b$ do not affect the left-hand side, so as long as both sides agree on the first $k$ bits, you can find a solution by setting the remaining bits of $b$ as necessary.
     * In other words, if $a^b \oplus a \equiv b \pmod{2^k}$, then $(a, a^b \oplus a \pmod{2^n})$ is a solution.
     * This lends itself to the method of computing all $2^k$ powers of $a$ (actually, you only need the $2^{k-1}$ even powers of $a$) and "extending" the bits to $b$ to find all solutions.
       * Note: the observations in the table above suggest that every odd $a$ appears exactly once. This means for any odd $a$, there is a unique solution to $a^b \oplus a \equiv b \pmod{2^k}$ which gets "extended" to an actual solution. This is a formally expressible mapping, and so I think there should be a simple formula that I am missing to figure out for which $b$ this happens, but this is the furthest I was able to get.

# Code Organization

 * `pow_xor_confuse.py` - reference implementation for finding solutions to the problem
 * `pow_xor_confuse.zig` - fast implementation for finding solutions to the problem
 * `script.py` - runs a bunch of tests and stuff, like checking the fast implementation against the reference implementation
