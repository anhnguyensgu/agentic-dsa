// LeetCode 322. Coin Change -- bottom-up DP, O(coins * amount) time, O(amount) space.
// Kept line-for-line equivalent to coin_change.cpp and coin_change.rs.
//
// Uses libc directly (malloc/free/strtoull/printf) so the allocator and the
// process startup are the same glibc code the C++ and Rust binaries use.

extern "c" fn malloc(size: usize) ?*anyopaque;
extern "c" fn free(ptr: ?*anyopaque) void;
extern "c" fn strtoull(s: [*:0]const u8, end: ?*[*:0]u8, base: c_int) c_ulonglong;
extern "c" fn printf(fmt: [*:0]const u8, ...) c_int;

export fn coin_change(coins: [*]const u32, n: usize, amount: usize) i32 {
    const inf: u32 = @as(u32, @truncate(amount)) +% 1;
    const len = amount + 1;
    const raw = malloc(len * @sizeOf(u32)) orelse @trap();
    defer free(raw);
    const dp: []u32 = @as([*]u32, @ptrCast(@alignCast(raw)))[0..len];
    @memset(dp, inf);
    dp[0] = 0;
    for (coins[0..n]) |coin| {
        const c: usize = coin;
        var a: usize = c;
        while (a < len) : (a += 1) {
            const v = dp[a - c] +% 1;
            if (v < dp[a]) dp[a] = v;
        }
    }
    const best = dp[amount];
    return if (best > amount) -1 else @intCast(best);
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
