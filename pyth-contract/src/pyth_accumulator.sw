library;

use ::data_structures::{
    price::{
        Price,
        PriceFeed,
        PriceFeedId,
    },
    pyth_accumulator::AccumulatorUpdateType,
};

use std::{bytes::Bytes, constants::ZERO_B256};

pub const ACCUMULATOR_MAGIC: u32 = 0x504e4155; // Consider const as bytes
pub fn accumulator_magic_bytes() -> Bytes {
    let accumulator_magic_array = ACCUMULATOR_MAGIC.to_be_bytes();

    let mut accumulator_magic_bytes = Bytes::with_capacity(4);
    accumulator_magic_bytes.push(accumulator_magic_array[0]);
    accumulator_magic_bytes.push(accumulator_magic_array[1]);
    accumulator_magic_bytes.push(accumulator_magic_array[2]);
    accumulator_magic_bytes.push(accumulator_magic_array[3]);

    accumulator_magic_bytes
}

pub fn extract_price_feed_from_merkle_proof(
    digest: Bytes,
    encoded: Bytes,
    offset: u64,
) -> (u64, PriceFeed, PriceFeedId) {
    //PLACEHOLDER 
    let price = Price {
        confidence: 0,
        exponent: 0,
        price: 0,
        publish_time: 0,
    };
    let price_feed = PriceFeed {
        ema_price: price,
        id: ZERO_B256,
        price: price,
    };
    (1u64, price_feed, ZERO_B256)
}

pub fn extract_update_type_from_accumulator_header(
    accumulator_update: Bytes,
) -> (u64, AccumulatorUpdateType) {
    //PLACEHOLDER 
    (1u64, AccumulatorUpdateType::WormholeMerkle)
}

pub fn parse_wormhole_merkle_header_updates(offset: u64, wormhole_merkle_update: Bytes) -> u64 {
    //PLACEHOLDER 
    1u64
}
