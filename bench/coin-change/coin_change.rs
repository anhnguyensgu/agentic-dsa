// LeetCode 322. Coin Change -- bottom-up DP, O(coins * amount) time, O(amount) space.
// Kept line-for-line equivalent to coin_change.cpp and coin_change.zig.
//
// Built twice: safe indexing (default), and `--cfg unchecked`, which drops the
// bounds checks the way C++ `operator[]` and Zig ReleaseFast do.

#[no_mangle]
#[inline(never)]
pub fn coin_change(coins: &[u32], amount: usize) -> i32 {
    let inf = amount as u32 + 1;
    let len = amount + 1;
    let mut dp = vec![inf; len];
    dp[0] = 0;
    for &coin in coins {
        let c = coin as usize;
        for a in c..len {
            #[cfg(not(unchecked))]
            {
                let v = dp[a - c].wrapping_add(1);
                if v < dp[a] {
                    dp[a] = v;
                }
            }
            #[cfg(unchecked)]
            unsafe {
                let v = dp.get_unchecked(a - c).wrapping_add(1);
                if v < *dp.get_unchecked(a) {
                    *dp.get_unchecked_mut(a) = v;
                }
            }
        }
    }
    let best = dp[amount];
    if best as usize > amount { -1 } else { best as i32 }
}

// usage: coin_change <reps> <amount> <coin>...
fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() < 4 {
        std::process::exit(2);
    }
    let reps: usize = args[1].parse().unwrap();
    let amount: usize = args[2].parse().unwrap();
    let coins: Vec<u32> = args[3..].iter().map(|s| s.parse().unwrap()).collect();

    let mut sum: i64 = 0;
    for r in 0..reps {
        let d = r & 7;
        let amt = if d > amount { amount } else { amount - d };
        sum += coin_change(&coins, amt) as i64;
    }
    println!("{sum}");
}
