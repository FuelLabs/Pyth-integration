library;

use ::data_structures::price::{Price, PriceFeed, PriceFeedId};
use ::errors::{PythError};

use std::{bytes::Bytes, constants::ZERO_B256};

const BATCH_MAGIC: u32 = 0x50325748;

pub struct BatchAttestationUpdate {
    data: Bytes,
}

impl BatchAttestationUpdate {
    pub fn new(data: Bytes) -> Self {
        Self { data }
    }
}

// more verification than parsing
pub fn parse_batch_attestation_header(encoded_payload: Bytes) -> (u64, u16, u16) {
    let mut index = 0;

    //Check header
    let magic = u32::from_be_bytes([
        encoded_payload.get(index).unwrap(),
        encoded_payload.get(index + 1).unwrap(),
        encoded_payload.get(index + 2).unwrap(),
        encoded_payload.get(index + 3).unwrap(),
    ]);
    require(magic == BATCH_MAGIC, PythError::InvalidUpdateData);
    index += 4;

    let major_version = u16::from_be_bytes([
        encoded_payload.get(index).unwrap(),
        encoded_payload.get(index + 1).unwrap(),
    ]);
    require(major_version == 3, PythError::InvalidUpdateData);
    // addtionally skip minor_version(2 bytes) as unused
    index += 4;

    let header_size = u16::from_be_bytes([
        encoded_payload.get(index).unwrap(),
        encoded_payload.get(index + 1).unwrap(),
    ]);
    index += 2;

    // From solidity impl:
    // NOTE(2022-04-19): Currently, only payloadId comes after
    // hdrSize. Future extra header fields must be read using a
    // separate offset to respect hdrSize, i.e.:
    // uint hdrIndex = 0;
    // bpa.header.payloadId = UnsafeBytesLib.toUint8(encoded, index + hdrIndex);
    // hdrIndex += 1;
    // bpa.header.someNewField = UnsafeBytesLib.toUint32(encoded, index + hdrIndex);
    // hdrIndex += 4;
    // Skip remaining unknown header bytes
    // index += bpa.header.hdrSize;

    let payload_id = encoded_payload.get(index).unwrap();

    // Payload ID of 2 required for batch header
    require(payload_id == 2, PythError::InvalidUpdateData);

    // Skip remaining unknown header bytes
    index += header_size.as_u64();

    let number_of_attestations = u16::from_be_bytes([
        encoded_payload.get(index).unwrap(),
        encoded_payload.get(index + 1).unwrap(),
    ]);
    index += 2;

    let attestation_size = u16::from_be_bytes([
        encoded_payload.get(index).unwrap(),
        encoded_payload.get(index + 1).unwrap(),
    ]);
    index += 2;

    require(encoded_payload.len == index + (attestation_size * number_of_attestations).as_u64(), PythError::InvalidUpdateData);

    return (index, number_of_attestations, attestation_size);
}

pub fn parse_single_attestation_from_batch(
    attestation_size: u16,
    encoded_payload: Bytes,
    index: u64,
) -> PriceFeed {
    // Skip product id (32 bytes) as unused
    let mut attestation_index = index + 32;

    let (_, slice) = encoded_payload.split_at(attestation_index);
    let (price_feed_id, _) = slice.split_at(32);
    let price_feed_id: PriceFeedId = price_feed_id.into();
    attestation_index += 32;

    let price = u64::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
        encoded_payload.get(attestation_index + 4).unwrap(),
        encoded_payload.get(attestation_index + 5).unwrap(),
        encoded_payload.get(attestation_index + 6).unwrap(),
        encoded_payload.get(attestation_index + 7).unwrap(),
    ]);
    attestation_index += 8;

    let confidence = u64::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
        encoded_payload.get(attestation_index + 4).unwrap(),
        encoded_payload.get(attestation_index + 5).unwrap(),
        encoded_payload.get(attestation_index + 6).unwrap(),
        encoded_payload.get(attestation_index + 7).unwrap(),
    ]);
    attestation_index += 8;

    // exponent is an i32, expected to be in the range -255 to 0
    let exponent = u32::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
    ]);
    let exponent = absolute_of_exponent(exponent);
    require(exponent < 256u32, PythError::InvalidExponent);
    attestation_index += 4;

    let ema_price = u64::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
        encoded_payload.get(attestation_index + 4).unwrap(),
        encoded_payload.get(attestation_index + 5).unwrap(),
        encoded_payload.get(attestation_index + 6).unwrap(),
        encoded_payload.get(attestation_index + 7).unwrap(),
    ]);
    attestation_index += 8;

    let ema_confidence = u64::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
        encoded_payload.get(attestation_index + 4).unwrap(),
        encoded_payload.get(attestation_index + 5).unwrap(),
        encoded_payload.get(attestation_index + 6).unwrap(),
        encoded_payload.get(attestation_index + 7).unwrap(),
    ]);
    attestation_index += 8;

    // Status is an enum (encoded as u8) with the following values:
    // 0 = UNKNOWN: The price feed is not currently updating for an unknown reason.
    // 1 = TRADING: The price feed is updating as expected.
    // 2 = HALTED: The price feed is not currently updating because trading in the product has been halted.
    // 3 = AUCTION: The price feed is not currently updating because an auction is setting the price.
    let status = encoded_payload.get(attestation_index).unwrap();
    // Additionally skip number_of publishers (8 bytes) and attestation_time (8 bytes); as unused
    attestation_index += 17;

    let publish_time = u64::from_be_bytes([
        encoded_payload.get(attestation_index).unwrap(),
        encoded_payload.get(attestation_index + 1).unwrap(),
        encoded_payload.get(attestation_index + 2).unwrap(),
        encoded_payload.get(attestation_index + 3).unwrap(),
        encoded_payload.get(attestation_index + 4).unwrap(),
        encoded_payload.get(attestation_index + 5).unwrap(),
        encoded_payload.get(attestation_index + 6).unwrap(),
        encoded_payload.get(attestation_index + 7).unwrap(),
    ]);
    attestation_index += 8;

    if status == 1u8 {
        attestation_index += 24;
    } else {
        // If status is not trading then the latest available price is
        // the previous price that is parsed here.

        // previous publish time
        let publish_time = u64::from_be_bytes([
            encoded_payload.get(attestation_index).unwrap(),
            encoded_payload.get(attestation_index + 1).unwrap(),
            encoded_payload.get(attestation_index + 2).unwrap(),
            encoded_payload.get(attestation_index + 3).unwrap(),
            encoded_payload.get(attestation_index + 4).unwrap(),
            encoded_payload.get(attestation_index + 5).unwrap(),
            encoded_payload.get(attestation_index + 6).unwrap(),
            encoded_payload.get(attestation_index + 7).unwrap(),
        ]);
        attestation_index += 8;

        // previous price
        let price = u64::from_be_bytes([
            encoded_payload.get(attestation_index).unwrap(),
            encoded_payload.get(attestation_index + 1).unwrap(),
            encoded_payload.get(attestation_index + 2).unwrap(),
            encoded_payload.get(attestation_index + 3).unwrap(),
            encoded_payload.get(attestation_index + 4).unwrap(),
            encoded_payload.get(attestation_index + 5).unwrap(),
            encoded_payload.get(attestation_index + 6).unwrap(),
            encoded_payload.get(attestation_index + 7).unwrap(),
        ]);
        attestation_index += 8;

        // previous confidence
        let confidence = u64::from_be_bytes([
            encoded_payload.get(attestation_index).unwrap(),
            encoded_payload.get(attestation_index + 1).unwrap(),
            encoded_payload.get(attestation_index + 2).unwrap(),
            encoded_payload.get(attestation_index + 3).unwrap(),
            encoded_payload.get(attestation_index + 4).unwrap(),
            encoded_payload.get(attestation_index + 5).unwrap(),
            encoded_payload.get(attestation_index + 6).unwrap(),
            encoded_payload.get(attestation_index + 7).unwrap(),
        ]);
        attestation_index += 8;
    }

    require((attestation_index - index) <= attestation_size.as_u64(), PythError::InvalidUpdateData);

    PriceFeed::new(Price::new(ema_confidence, exponent, ema_price, publish_time), price_feed_id, Price::new(confidence, exponent, price, publish_time))
}

// utils::absolute_of_exponent temporarily moved to silence errors while importing from actual libs
fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}
