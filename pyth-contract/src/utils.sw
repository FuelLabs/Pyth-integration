library;

use ::data_structures::{price::{PriceFeedId}};
use std::bytes::Bytes;

pub fn difference(x: u64, y: u64) -> u64 {
    if x > y { x - y } else { y - x }
}

pub fn is_target_price_feed_id(
    target_price_feed_ids: Vec<PriceFeedId>,
    price_feed_id: PriceFeedId,
) -> bool {
    let mut i = 0;
    while i < target_price_feed_ids.len {
        if target_price_feed_ids.get(i).unwrap() == price_feed_id
        {
            return true;
        }
        i += 1;
    }

    false
}

pub fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}
