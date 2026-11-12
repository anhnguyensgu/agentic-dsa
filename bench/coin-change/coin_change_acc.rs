// LeetCode 322. Coin Change -- bottom-up DP, accumulator form.
//
// Same as coin_change.rs with the loops swapped: for each amount, reduce over
// the coins into one accumulator (`best`) held in a register, then store once.
// The table is written once per amount instead of once per (coin, amount).
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
    for a in 1..len {
        let mut best = inf;
        for &coin in coins {
            let c = coin as usize;
            if c <= a {
                #[cfg(not(unchecked))]
                let v = dp[a - c].wrapping_add(1);
                #[cfg(unchecked)]
                let v = unsafe { dp.get_unchecked(a - c).wrapping_add(1) };
                if v < best {
                    best = v;
                }
            }
        }
        #[cfg(not(unchecked))]
        {
            dp[a] = best;
        }
        #[cfg(unchecked)]
        unsafe {
            *dp.get_unchecked_mut(a) = best;
        }
    }
    let result = dp[amount];
    if result as usize > amount { -1 } else { result as i32 }
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
