const std = @import("std");

const Result = extern struct {
    a: u32,
    b: u32,
};

const Prog = struct {
    c: usize,
    vc: usize,
    vp: usize,

    inline fn prog1(p: *Prog, comptime mt: bool) usize {
        if (mt) {
            return @atomicRmw(usize, &p.c, .Add, 1, .monotonic);
        } else {
            defer p.c += 1;
            return p.c;
        }
    }

    inline fn update(p: *Prog, n: usize) void {
        if (p.c > p.vc) {
            std.io.getStdErr().writer().print("[{}/100]\r", .{p.vp}) catch {};
            p.vp += 1;
            p.vc = fraction(@as(usize, 1) << @intCast(n - 1), p.vp);
        }
    }

    inline fn fraction(n: usize, p: usize) usize {
        if (n > std.math.maxInt(usize) / 100) {
            return p * (n / 100);
        } else {
            return (p * n) / 100;
        }
    }
};

const Worker = struct {
    t: std.Thread,
    p: Prog,
};

pub fn main() !u8 {
    var gpa_instance: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa_instance.deinit() == .ok);
    const gpa = gpa_instance.allocator();

    const j, const n, const o, const v = args: {
        var n: u8 = 16;
        var o: ?[]const u8 = null;
        var v = false;
        var j: u4 = 0;
        var args: std.process.ArgIterator = try .initWithAllocator(gpa);

        if (!args.skip()) {
            break :args null;
        }
        while (args.next()) |opt| {
            if (std.mem.eql(u8, opt, "-j")) {
                const j_str = if (opt.len > 2) opt[2..] else args.next() orelse break :args null;
                const j_val = std.fmt.parseUnsigned(u16, j_str, 10) catch break :args null;
                if (@popCount(j_val) != 1) {
                    break :args null;
                }
                j = @intCast(@ctz(j_val));
            } else if (std.mem.eql(u8, opt, "-n")) {
                const n_str = if (opt.len > 2) opt[2..] else args.next() orelse break :args null;
                n = std.fmt.parseUnsigned(u8, n_str, 10) catch break :args null;
                if (n > 32) {
                    break :args null;
                }
            } else if (std.mem.startsWith(u8, opt, "-o")) {
                o = if (opt.len > 2) opt[2..] else args.next() orelse break :args null;
            } else if (std.mem.eql(u8, opt, "-v")) {
                v = true;
            } else {
                break :args null;
            }
        }
        break :args .{ @min(j, n -| 4), n, o, v };
    } orelse {
        try std.io.getStdErr().writeAll(
            \\Usage: pow_xor_confuse -n <0...32> [-j <nthreads>] [-o <file.csv>] [-v]
            \\
            \\  Find all integer solutions (a, b) to the system
            \\    0 <= a < 2^n
            \\    0 <= b < 2^n
            \\    a xor b = a^b (mod 2^n)
            \\  where '^' denotes exponentiation.
            \\
            \\Options:
            \\ -n <0...32>     Change the modulus to compute under. Required.
            \\ -j <nthreads>   Run on <nthreads> threads. Must be a power of 2 less than 65536.
            \\ -o <file.csv>   Write to <file.csv> instead of to stdout.
            \\ -v              Enable progress tracking (needs isatty stderr).
            \\ -h              Print this message.
            \\
        );
        return 1;
    };

    const out_file = if (o) |filename| try std.fs.cwd().createFile(filename, .{}) else null;
    defer if (out_file) |file| file.close();
    var bw = std.io.bufferedWriter(if (out_file) |file| file.writer() else std.io.getStdOut().writer());
    var writer = bw.writer();

    const m = if (n == 32) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(n)) - 1;
    const num_odd_a = if (n == 0) 0 else @as(u32, 1) << @intCast(n - 1);

    const results = try gpa.alloc(Result, if (n == 0) 1 else m);
    defer gpa.free(results);


    pow_xor_confuse_even_a(results[num_odd_a..], n);
    if (j != 0) {
        const ws = try gpa.alignedAlloc(Worker, 64, @as(usize, 1) << j);
        defer gpa.free(ws);
        @memset(ws, .{ .t = undefined, .p = .{ .c = 0, .vc = 0, .vp = 0  } });

        const num_per_w = num_odd_a >> j;
        for (ws, 0..) |*w, ji| {
            w.t = try std.Thread.spawn(.{}, pow_xor_confuse_odd_a, .{ true, results[num_per_w * ji ..][0..num_per_w], n, &w.p, j, @as(u32, @intCast(ji)), false });
        }
        if (v) {
            var p: Prog = .{ .c = 0, .vc = 0, .vp = 0 };
            while (p.c != num_odd_a) {
                std.Thread.sleep(50 * std.time.ms_per_s);
                p.c = 0;
                for (ws) |*w| {
                    p.c += @atomicLoad(usize, &w.p.c, .monotonic);
                }
                p.update(n);
            }
        }
        for (ws) |w| {
            w.t.join();
        }
    } else {
        var p: Prog = .{ .c = 0, .vc = 0, .vp = 0 };
        pow_xor_confuse_odd_a(false, results[0..num_odd_a], n, &p, 0, 0, v);
    }

    try writer.writeAll("a,b\n");
    for (results) |result| {
        try writer.print("{},{}\n", .{ result.a, result.b });
    }
    try bw.flush();

    return 0;
}

fn pow_xor_confuse_even_a(r: []Result, n: u32) void {
    if (n == 0) {
        @memcpy(r, &[_]Result{.{ .a = 0, .b = 0 }});
        return;
    } 
    if (n == 1) {
        return;
    } 
    if (n == 2) {
        @memcpy(r, &[_]Result{ .{ .a = 2, .b = 2 } });
        return;
    } 
    if (n == 3) {
        @memcpy(r, &[_]Result{ .{ .a = 4, .b = 4 }, .{ .a = 6, .b = 2 }, .{ .a = 6, .b = 6 } });
        return;
    }
    var c: usize = 0;
    const m = if (n == 0) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(n)) - 1;
    const ms: @Vector(4, u32) = @splat(m);
    const ns: @Vector(4, u32) = @splat(n);
    var as: @Vector(4, u32) = .{ 0, 2, 4, 6 };
    for (0..@as(u32, 1) << @intCast(n - 3)) |_| {
        const a2s = as *% as;
        var ps: @Vector(4, u32) = @splat(1);
        var b: u32 = 0;
        while (b < n) : (b += 2) {
            const ds = as ^ @as(@Vector(4, u32), @splat(b)) == ps & ms;
            for (0..4) |i| {
                if (ds[i]) {
                    r[c] = .{ .a = as[i], .b = b };
                    c += 1;
                }
            }
            ps = (a2s *% ps);
        }
        const ds = as >= ns;
        for (0..4) |i| {
            if (ds[i]) {
                r[c] = .{ .a = as[i], .b = as[i] };
                c += 1;
            }
        }
        as +%= @splat(8);
    }
}

fn pow_xor_confuse_odd_a(comptime mt: bool, r: []Result, n: u32, p: *Prog, j: u32, ji: u32, v: bool) void {
    if (n == 0) {
        return;
    } 
    if (n == 1) {
        @memcpy(r, &[_]Result{.{ .a = 1, .b = 0 }});
        return;
    } 
    if (n == 2) {
        @memcpy(r, &[_]Result{ .{ .a = 1, .b = 0 }, .{ .a = 3, .b = 2 } });
        return;
    } 
    if (n == 3) {
        @memcpy(r, &[_]Result{ .{ .a = 1, .b = 0 }, .{ .a = 3, .b = 2 }, .{ .a = 5, .b = 4 }, .{ .a = 7, .b = 6 } });
        return;
    }

    const m = if (n == 0) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(n)) - 1;
    const ms: @Vector(4, u32) = @splat(m);

    if (ji == 0) {
        r[p.prog1(mt)] = .{ .a = 1, .b = 0 };
        if (v) p.update(n);
    }

    var as = @Vector(4, u32){ 1, 3, 5, 7 } + @as(@Vector(4, u32), @splat(ji << @intCast(n - j)));
    for (0..@as(u32, 1) << @intCast(n - 3 - j)) |_| {
        var ks: @Vector(4, u32) = @splat(0);
        var ps = as;
        while (@reduce(.Or, ps != @as(@Vector(4, u32), @splat(1)))) {
            ks = @select(u32, ps != @as(@Vector(4, u32), @splat(1)), ks + @as(@Vector(4, u32), @splat(1)), ks);
            ps = (ps *% ps) & ms;
        }
        for (0..4) |i| {
            const ah = as[i];
            const kh = ks[i];
            if (kh == 0) {} else if (kh == 1) {
                r[p.prog1(mt)] = .{ .a = ah, .b = ah & ~@as(u32, 1) };
                if (v) p.update(n);
            } else if (kh == 2) {
                if (1 == ah & 3) {
                    r[p.prog1(mt)] = .{ .a = ah, .b = ah & ~@as(u32, 1) };
                    if (v) p.update(n);
                }
                const bh = (ah ^ (ah *% ah)) & m;
                if (2 == bh & 3) {
                    r[p.prog1(mt)] = .{ .a = ah, .b = bh };
                    if (v) p.update(n);
                }
            } else {
                const mhs: @Vector(4, u32) = @splat((@as(u32, 1) << @intCast(kh)) - 1);
                const ahs: @Vector(4, u32) = @splat(ah);
                var bhs: @Vector(4, u32) = .{ 0, 2, 4, 6 };
                var phs: @Vector(4, u32) = undefined;
                phs[0] = 1;
                phs[1] = ah *% ah *% phs[0];
                phs[2] = ah *% ah *% phs[1];
                phs[3] = ah *% ah *% phs[2];
                const ahs8: @Vector(4, u32) = @splat(ah *% ah *% phs[3]);
                b_loop: for (0..@as(u32, 1) << @intCast(kh - 3)) |_| {
                    const dhs = bhs == (ahs ^ phs) & mhs;
                    for (0..4) |ii| {
                        if (dhs[ii]) {
                            r[p.prog1(mt)] = .{ .a = ah, .b = (ah ^ phs[ii]) & m };
                            if (v) p.update(n);
                            break :b_loop;
                        }
                    }
                    phs = (ahs8 *% phs);
                    bhs +%= @splat(8);
                }
            }
        }
        as +%= @splat(8);
    }
}
