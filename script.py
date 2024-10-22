from io import StringIO
from pow_xor_confuse import pow_xor_confuse
import pandas
import subprocess
import multiprocessing

def system(l, **kwargs):
    print(f">>> {" ".join(l)}")
    return subprocess.run(l, check=True, **kwargs)
def comma_sep(s):
    return ", ".join(map(str,s))

class Script:
    def __init__(self, N, N_ref):
        self.zig_runs = [None for _ in range(N + 1)]
        self.py_runs = [None for _ in range(N_ref + 1)]

        system(["zig", "build-exe", "pow_xor_confuse.zig", "-OReleaseFast"])
        print()
        for n in range(0, N_ref + 1):
            self.py_runs[n] = pandas.DataFrame(pow_xor_confuse(n), columns=["a", "b"])
        for n in range(0, N + 1):
            r = system(["./pow_xor_confuse", "-n", str(n), "-o", f"pow-xor-confuse.{n}.csv"], text=True, capture_output=True)
            self.zig_runs[n] = (pandas.read_csv(f"pow-xor-confuse.{n}.csv"), [], [])
    
    def count_exceptions(self):
        for n, (df, a_counts, b_counts) in enumerate(self.zig_runs):
            a_counts = df["a"].value_counts()
            for a in range(1 << n):
                if (count := a_counts.get(a, 0)) != 1:
                    if count == 0:
                        self.zig_runs[n][1].append(a)
                    elif count == 2:
                        self.zig_runs[n][2].append(a)
                    else:
                        print(f"  NEW EXCEPTION: a={a}, freq={count or 0}")
            b_counts = df["b"].value_counts()
            for b in range(1 << n):
                if (count := b_counts.get(b, 0)) != (1 if b == 0 else 0 if b % 2 == 1 else 2):
                    print(f"  NEW EXCEPTION: b={b}, freq={count or 0}")

    def test_correctness(self):
        for n, (df_py, (df_zig, _, _)) in enumerate(zip(self.py_runs, self.zig_runs)):
            print(f"Checking {n}...")
            df_py_sorted = df_py.sort_values(by=["a","b"])
            df_py_sorted = df_py_sorted.reset_index(drop=True)
            df_zig_sorted = df_zig.sort_values(by=["a","b"])
            df_zig_sorted = df_zig_sorted.reset_index(drop=True)
            pandas.testing.assert_frame_equal(df_py_sorted, df_zig_sorted)

    def print_table(self):
        H0 = "$n$"
        H1 = "values $a$ with no appearances"
        H2 = "values $a$ with 2 appearances"
        W0 = max(len(H0), len(str(len(self.zig_runs) - 1)))
        W1 = max(len(H1), len(comma_sep(self.zig_runs[-1][1])))
        W2 = max(len(H2), len(comma_sep(self.zig_runs[-1][2])))
        print(f"| {H0:<{W0}} | {H1:<{W1}} | {H2:<{W2}} |")
        for n, (_, zero_as, two_as) in enumerate(self.zig_runs):
            print(f"| {n:<{W0}} | {comma_sep(zero_as):<{W1}} | {comma_sep(two_as):<{W2}} |")

if __name__ == "__main__":
    s = Script(20, 10)
    s.test_correctness()
    s.count_exceptions()
    s.print_table()
