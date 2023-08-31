library;

use ::data_structures::{price::{PriceFeedId}};
use ::pyth_accumulator::{accumulator_magic_bytes, AccumulatorUpdate};

use std::bytes::Bytes;

pub enum UpdateType {
    Accumulator: AccumulatorUpdate,
    BatchAttestation: (),
}

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

pub fn update_type(data: Bytes) -> UpdateType {
    let (magic, _) = data.split_at(4);
    if data.len > 4 && magic == accumulator_magic_bytes() {
        UpdateType::Accumulator(AccumulatorUpdate::new(data))
    } else {
        UpdateType::BatchAttestation
    }
}

pub fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}
