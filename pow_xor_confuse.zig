const std = @import("std");

const Result = struct {
    a: u32,
    b: u32,
};

pub fn main() !u8 {
    const out = std.io.getStdOut();
    const err = std.io.getStdErr();
    var gpa_instance: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer std.debug.assert(gpa_instance.deinit() == .ok);
    const gpa = gpa_instance.allocator();

    const j, const n, const o, const v = args: {
        var n: u8 = 16;
        var o: ?[]const u8 = null;
        var v = false;
        var j: u16 = 1;
        var args: std.process.ArgIterator = try .initWithAllocator(gpa);

        if (!args.skip()) {
            break :args null;
        }
        while (args.next()) |opt| {
            if (std.mem.eql(u8, opt, "-j")) {
                j = std.fmt.parseUnsigned(u16, args.next() orelse break :args null, 10) catch
                    break :args null;
                if (@popCount(j) != 1) {
                    break :args null;
                }
                try err.writeAll("warning: -j not supported yet\n");
            } else if (std.mem.eql(u8, opt, "-n")) {
                n = std.fmt.parseUnsigned(u8, args.next() orelse break :args null, 10) catch
                    break :args null;
                if (n > 32) {
                    break :args null;
                }
            } else if (std.mem.eql(u8, opt, "-o")) {
                o = args.next() orelse break :args null;
            } else if (std.mem.eql(u8, opt, "-v")) {
                v = true;
                try err.writeAll("warning: -v not supported yet\n");
            } else {
                break :args null;
            }
        }
        if (j != 1 and v) {
            break :args null;
        }
        break :args .{ j, n, o, v };
    } orelse {
        try err.writeAll(
            \\Usage: pow_xor_confuse -n <0...32> [-j nthreads] [-o file] [-v]
            \\
            \\  Find all integer solutions (a, b) to the system
            \\    0 <= a < 2^n
            \\    0 <= b < 2^n
            \\    a xor b = a^b (mod 2^n)
            \\  where '^' denotes exponentiation.
            \\
            \\Options:
            \\ -n <0...32>   Change the modulus to compute under. Required.
            \\ -j nthreads   Number of threads to run on. Must be a power of 2.
            \\ -o file.csv   Write to file.csv instead of to stdout.
            \\ -v            Enable progress tracking (needs isatty stderr and -j not set).
            \\ -h            Print this message.
            \\
        );
        return 1;
    };

    _ = j; // TODO: implement
    _ = v; // TODO: implement

    const results, const is_alloc = try pow_xor_confuse(gpa, n);
    defer if (is_alloc) gpa.free(results);

    const out_file = if (o) |filename| try std.fs.cwd().createFile(filename, .{}) else null;
    defer if (out_file) |file| file.close();
    var bw = std.io.bufferedWriter(if (out_file) |file| file.writer() else out.writer());
    var writer = bw.writer();

    try writer.writeAll("a,b\n");
    for (results) |result| {
        try writer.print("{},{}\n", .{ result.a, result.b });
    }
    try bw.flush();

    return 0;
}

fn pow_xor_confuse(gpa: std.mem.Allocator, n: u32) !struct { []const Result, bool } {
    if (n == 0) {
        return .{ &.{.{ .a = 0, .b = 0 }}, false };
    } else if (n == 1) {
        return .{ &.{.{ .a = 1, .b = 0 }}, false };
    } else if (n == 2) {
        return .{ &.{ .{ .a = 1, .b = 0 }, .{ .a = 2, .b = 2 }, .{ .a = 3, .b = 2 } }, false };
    } else if (n == 3) {
        return .{ &.{
            .{ .a = 1, .b = 0 }, .{ .a = 3, .b = 2 },
            .{ .a = 4, .b = 4 }, .{ .a = 5, .b = 4 },
            .{ .a = 6, .b = 2 }, .{ .a = 6, .b = 6 },
            .{ .a = 7, .b = 6 },
        }, false };
    }

    const m = if (n == 0) std.math.maxInt(u32) else (@as(u32, 1) << @intCast(n)) - 1;
    const ms: @Vector(4, u32) = @splat(m);
    const ns: @Vector(4, u32) = @splat(n);

    var r: []Result = try gpa.alloc(Result, m);
    errdefer gpa.free(r);
    var c: usize = 0;

    r[0] = .{ .a = 1, .b = 0 };
    c += 1;

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
    as = .{ 1, 3, 5, 7 };
    for (0..@as(u32, 1) << @intCast(n - 3)) |_| {
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
                r[c] = .{ .a = ah, .b = ah & ~@as(u32, 1) };
                c += 1;
            } else if (kh == 2) {
                if (1 == ah & 3) {
                    r[c] = .{ .a = ah, .b = ah & ~@as(u32, 1) };
                    c += 1;
                }
                const bh = (ah ^ (ah *% ah)) & m;
                if (2 == bh & 3) {
                    r[c] = .{ .a = ah, .b = bh };
                    c += 1;
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
                    for (0..4) |j| {
                        if (dhs[j]) {
                            r[c] = .{ .a = ah, .b = (ah ^ phs[j]) & m };
                            c += 1;
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

    return .{ r, true };
}
