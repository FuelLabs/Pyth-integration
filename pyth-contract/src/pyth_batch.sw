library;

use ::data_structures::price::{Price, PriceFeed};

use std::{bytes::Bytes, constants::ZERO_B256};

pub struct BatchAttestationUpdate {
    data: Bytes,
}

pub fn parse_batch_attestation_header(encoded_payload: Bytes) -> (u64, u64, u64) {
    //PLACEHOLDER 
    (1, 1, 1)
}

pub fn parse_single_attestation_from_batch(
    attestations_index: u64,
    attestation_size: u64,
    encoded_payload: Bytes,
) -> PriceFeed {
    //PLACEHOLDER 
    let price = Price::new(1u64, 1u32, 1u64, 1u64);
    PriceFeed::new(price, ZERO_B256, price)
}
