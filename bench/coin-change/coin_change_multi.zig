// LeetCode 322. Coin Change -- bottom-up DP, accumulator form with four
// independent accumulators.
//
// Same as coin_change_acc.zig except that the reduction over coins is unrolled
// by four, each lane keeping its own running minimum, combined once at the
// end. A single accumulator makes every min wait for the previous one; four
// accumulators let the CPU work on four candidates at the same time.
//
// Uses libc directly (malloc/free/strtoull/printf) so the allocator and the
// process startup are the same glibc code the C++ and Rust binaries use.

extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;
extern "c" fn strtoull(s: [*:0]const u8, end: ?*[*:0]u8, base: c_int) c_ulonglong;
extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;

inline fn relax(dp: []const u32, a: usize, coin: u32, best: u32) u32 {
    const c: usize = coin;
    if (c <= a) {
        const v = dp[a - c] +% 1;
        if (v < best) return v;
    }
    return best;
}

export fn coin_change(coins: [*]const u32, n: usize, amount: usize) i32 {
    const inf: u32 = @as(u32, @truncate(amount)) +% 1;
    const len = amount + 1;
    const raw = malloc(len * @sizeOf(u32)) orelse @trap();
    defer free(raw);
    const dp: []u32 = @as([*]u32, @ptrCast(@alignCast(raw)))[0..len];
    @memset(dp, inf);
    dp[0] = 0;
    var a: usize = 1;
    while (a < len) : (a += 1) {
        var b0 = inf;
        var b1 = inf;
        var b2 = inf;
        var b3 = inf;
        var i: usize = 0;
        while (i + 4 <= n) : (i += 4) {
            b0 = relax(dp, a, coins[i], b0);
            b1 = relax(dp, a, coins[i + 1], b1);
            b2 = relax(dp, a, coins[i + 2], b2);
            b3 = relax(dp, a, coins[i + 3], b3);
        }
        while (i < n) : (i += 1) b0 = relax(dp, a, coins[i], b0);
        dp[a] = @min(@min(b0, b1), @min(b2, b3));
    }
    const result = dp[amount];
    return if (result > amount) -1 else @intCast(result);
}

// usage: coin_change <reps> <amount> <coin>...
pub export fn main(argc: c_int, argv: [*][*:0]u8) c_int {
    if (argc < 4) return 2;
    const reps: usize = strtoull(argv[1], null, 10);
    const amount: usize = strtoull(argv[2], null, 10);
    const n: usize = @intCast(argc - 3);
    const coins: [*]u32 = @ptrCast(@alignCast(malloc(n * @sizeOf(u32)) orelse @trap()));
    for (0..n) |i| coins[i] = @truncate(strtoull(argv[3 + i], null, 10));

    var sum: i64 = 0;
    for (0..reps) |r| {
        const d = r & 7;
        const amt = if (d > amount) amount else amount - d;
        sum += @call(.never_inline, coin_change, .{ coins, n, amt });
    }
    _ = printf("%lld\n", @as(c_longlong, sum));
    return 0;
}
