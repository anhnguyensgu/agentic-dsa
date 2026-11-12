// LeetCode 322. Coin Change -- bottom-up DP, accumulator form with four
// independent accumulators.
//
// Same as coin_change_acc.rs except that the reduction over coins is unrolled
// by four, each lane keeping its own running minimum, combined once at the
// end. A single accumulator makes every min wait for the previous one; four
// accumulators let the CPU work on four candidates at the same time.
//
// Built twice: safe indexing (default), and `--cfg unchecked`, which drops the
// bounds checks the way C++ `operator[]` and Zig ReleaseFast do.

#[inline(always)]
fn relax(dp: &[u32], a: usize, coin: u32, best: u32) -> u32 {
    let c = coin as usize;
    if c <= a {
        #[cfg(not(unchecked))]
        let v = dp[a - c].wrapping_add(1);
        #[cfg(unchecked)]
        let v = unsafe { dp.get_unchecked(a - c).wrapping_add(1) };
        if v < best {
            return v;
        }
    }
    best
}

#[no_mangle]
#[inline(never)]
pub fn coin_change(coins: &[u32], amount: usize) -> i32 {
    let inf = amount as u32 + 1;
    let len = amount + 1;
    let mut dp = vec![inf; len];
    dp[0] = 0;
    for a in 1..len {
        let (mut b0, mut b1, mut b2, mut b3) = (inf, inf, inf, inf);
        let mut chunks = coins.chunks_exact(4);
        for ch in &mut chunks {
            b0 = relax(&dp, a, ch[0], b0);
            b1 = relax(&dp, a, ch[1], b1);
            b2 = relax(&dp, a, ch[2], b2);
            b3 = relax(&dp, a, ch[3], b3);
        }
        for &coin in chunks.remainder() {
            b0 = relax(&dp, a, coin, b0);
        }
        let best = b0.min(b1).min(b2.min(b3));
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
