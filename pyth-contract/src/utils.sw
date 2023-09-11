library;

use ::data_structures::{price::{PriceFeed, PriceFeedId}};
use std::bytes::Bytes;

pub fn difference(x: u64, y: u64) -> u64 {
    if x > y { x - y } else { y - x }
}

pub fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}
