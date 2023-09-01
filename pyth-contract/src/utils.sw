library;

use ::data_structures::{price::{PriceFeedId}};
use std::bytes::Bytes;

pub fn difference(x: u64, y: u64) -> u64 {
    if x > y { x - y } else { y - x }
}

pub fn find_index_of_price_feed_id(
    price_feed_ids: Vec<PriceFeedId>,
    target_price_feed_id: PriceFeedId,
) -> u64 {
    let mut index = 0;
    let price_feed_ids_length = price_feed_ids.len;
    while index < price_feed_ids_length {
        if price_feed_ids.get(index).unwrap() == target_price_feed_id
        {
            return index;
        }
        index += 1;
    }

    index
}

pub fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}
