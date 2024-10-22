from io import StringIO
from pow_xor_confuse import pow_xor_confuse
import argparse
import multiprocessing
import os
import pandas
import subprocess

def system(l, **kwargs):
    print(f">>> {" ".join(l)}")
    return subprocess.run(l, check=True, **kwargs)
def comma_sep(s):
    return ", ".join(map(str,s))

class Script:
    def __init__(self, N, M, j, v, w, O=False, tsan=False, valgrind=False):
        self.zig_runs = [None for _ in range(N + 1)]
        self.py_runs = [None for _ in range(M + 1)]

        cmd = ["zig", "build-exe", "pow_xor_confuse.zig"]
        if O:
            cmd.append("-OReleaseFast")
        if tsan:
            cmd.append("-fsanitize-thread")
        if valgrind:
            cmd.append("-fvalgrind")
        if w:
            os.makedirs("data", exist_ok=True)

        system(cmd)
        print()
        for n in range(0, M + 1):
            self.py_runs[n] = pandas.DataFrame(pow_xor_confuse(n), columns=["a", "b"])
        for n in range(0, N + 1):
            cmd = ["./pow_xor_confuse", "-n", str(n)]
            if valgrind:
                cmd.insert(0, "valgrind")
            if v:
                cmd.append("-v")
            if j != None:
                cmd.extend(["-j", str(j)])
            if w:
                cmd.extend(["-o", f"data/pow-xor-confuse.{n}.csv"])
                system(cmd)
                self.zig_runs[n] = pandas.read_csv(f"data/pow-xor-confuse.{n}.csv")
            else:
                r = system(cmd, text=True, stdout=subprocess.PIPE)
                self.zig_runs[n] = pandas.read_csv(StringIO(r.stdout))
    
    def correctness(self):
        for n, (df_py, df_zig) in enumerate(zip(self.py_runs, self.zig_runs)):
            print(f"Checking {n}...")
            df_py_sorted = df_py.sort_values(by=["a","b"])
            df_py_sorted = df_py_sorted.reset_index(drop=True)
            df_zig_sorted = df_zig.sort_values(by=["a","b"])
            df_zig_sorted = df_zig_sorted.reset_index(drop=True)
            pandas.testing.assert_frame_equal(df_py_sorted, df_zig_sorted)
        print("All checks passed!")

    def exceptions(self):
        a0_counts = [[] for _ in range(len(self.zig_runs))]
        a1_counts = [[] for _ in range(len(self.zig_runs))]
        for n, (a0, a1, df) in enumerate(zip(a0_counts, a1_counts, self.zig_runs)):
            a_counts = df["a"].value_counts()
            for a in range(1 << n):
                if (count := a_counts.get(a, 0)) != 1:
                    if count == 0:
                        a0.append(a)
                    elif count == 2:
                        a1.append(a)
                    else:
                        print(f"  NEW EXCEPTION: a={a}, freq={count or 0}")
            b_counts = df["b"].value_counts()
            for b in range(1 << n):
                if (count := b_counts.get(b, 0)) != (1 if b == 0 else 0 if b % 2 == 1 else 2):
                    print(f"  NEW EXCEPTION: b={b}, freq={count or 0}")
        H0 = "$n$"
        H1 = "values $a$ with no appearances"
        H2 = "values $a$ with 2 appearances"
        W0 = max(len(H0), len(str(len(self.zig_runs) - 1)))
        W1 = max(len(H1), len(comma_sep(a0_counts[-1])))
        W2 = max(len(H2), len(comma_sep(a1_counts[-1])))
        print(f"| {H0:<{W0}} | {H1:<{W1}} | {H2:<{W2}} |")
        for n, (a0, a1) in enumerate(zip(a0_counts, a1_counts)):
            print(f"| {n:<{W0}} | {comma_sep(a0):<{W1}} | {comma_sep(a1):<{W2}} |")

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description="Run implementations with various options.")
    parser.add_argument("-n", type=int, metavar="NITER", 
                        help="Run fast implementation on NITER different moduli from 1 to 2^NITER",
                        required=True)
    parser.add_argument("-m", type=int, metavar="NITER", 
                        help="Run reference implementation on NITER different moduli from 1 to 2^NITER",
                        required=True)
    parser.add_argument("-j", type=int, metavar="NTHREADS", 
                        help="Run on NTHREADS threads")
    parser.add_argument("-v", action="store_true", 
                        help="Enable progress tracking (requires stderr to be a tty)")
    parser.add_argument("-w", action="store_true", 
                        help="Save output of fast implementation to files")
    parser.add_argument("-O", action="store_true", 
                        help="Enable optimizations in fast implementation")
    parser.add_argument("--tsan", action="store_true", 
                        help="Enable thread sanitization")
    parser.add_argument("--valgrind", action="store_true", 
                        help="Enable sanitization with valgrind")

    args = parser.parse_args()
    s = Script(N=args.n, M=args.m, j=args.j, v=args.v, w=args.w, O=args.O, tsan=args.tsan, valgrind=args.valgrind)
    s.correctness()
    s.exceptions()
