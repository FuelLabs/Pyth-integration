library;

use ::data_structures::{price::{Price, PriceFeed, PriceFeedId}};
use ::errors::{PythError};

use std::{bytes::Bytes, constants::ZERO_B256};

const ACCUMULATOR_MAGIC: u32 = 0x504e4155; // Consider const as bytes and removing accumulator_magic_bytes
const MINIMUM_ALLOWED_MINOR_VERSION = 0;
const MAJOR_VERSION = 1;

pub struct AccumulatorUpdate {
    data: Bytes,
}

impl AccumulatorUpdate {
    pub fn new(data: Bytes) -> Self {
        Self { data }
    }

    pub fn total_updates(self, ref mut offset: u64) -> u64 {
        //two bytes starting at offset
        let proof_size = u16::from_be_bytes([
            self.data.get(offset).unwrap(),
            self.data.get(offset + 1).unwrap(),
        ]).as_u64();

        offset += proof_size + 2;

        self.data.get(offset).unwrap().as_u64()
    }

    pub fn verify(self) -> u64 {
        // skip magic as already checked when this is called
        let major_version = self.data.get(4);
        require(major_version.is_some() && major_version.unwrap() == MAJOR_VERSION, PythError::InvalidUpdateData);

        let minor_version = self.data.get(5);
        require(minor_version.is_some() && minor_version.unwrap() >= MINIMUM_ALLOWED_MINOR_VERSION, PythError::InvalidUpdateData);

        let trailing_header_size = self.data.get(6);
        require(trailing_header_size.is_some(), PythError::InvalidUpdateData);

        // skip trailing headers and update type
        let offset = 8 + trailing_header_size.unwrap().as_u64();

        require(self.data.len >= offset, PythError::InvalidUpdateData);

        offset
    }
}

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
    encoded_proof: Bytes,
    ref mut offset: u64,
) -> (u64, PriceFeed) {
    let message_size = u16::from_be_bytes([
        encoded_proof.get(offset).unwrap(),
        encoded_proof.get(offset + 1).unwrap(),
    ]).as_u64();
    offset += 2;

    let (_, slice) = encoded_proof.split_at(offset);
    let (encoded_message, _) = slice.split_at(message_size);
    offset += message_size;

    let end_offset = validate_proof(encoded_proof, encoded_message, offset, digest);

    // Message type of 0 is a Price Feed
    require(encoded_message.get(0).unwrap() == 0, PythError::IncorrectMessageType);
    let price_feed = parse_price_feed_message(encoded_message);
    (end_offset, price_feed)
}

fn parse_price_feed_message(encoded_price_feed: Bytes) -> PriceFeed {
    let mut offset = 1u64;

    let (_, slice) = encoded_price_feed.split_at(offset);
    let (price_feed_id, _) = slice.split_at(32);
    let price_feed_id: PriceFeedId = price_feed_id.into();
    offset += 32;

    let price = u64::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
        encoded_price_feed.get(offset + 4).unwrap(),
        encoded_price_feed.get(offset + 5).unwrap(),
        encoded_price_feed.get(offset + 6).unwrap(),
        encoded_price_feed.get(offset + 7).unwrap(),
    ]);
    offset += 8;

    let confidence = u64::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
        encoded_price_feed.get(offset + 4).unwrap(),
        encoded_price_feed.get(offset + 5).unwrap(),
        encoded_price_feed.get(offset + 6).unwrap(),
        encoded_price_feed.get(offset + 7).unwrap(),
    ]);
    offset += 8;

    // exponent is an i32, expected to be in the range -255 to 0
    let exponent = u32::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
    ]);
    let exponent = absolute_of_exponent(exponent);
    require(exponent < 256u32, PythError::InvalidExponent);
    offset += 4;

    let publish_time = u64::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
        encoded_price_feed.get(offset + 4).unwrap(),
        encoded_price_feed.get(offset + 5).unwrap(),
        encoded_price_feed.get(offset + 6).unwrap(),
        encoded_price_feed.get(offset + 7).unwrap(),
    ]);
    // skip unused previous_publish_times (8 bytes)
    offset += 16;

    let ema_price = u64::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
        encoded_price_feed.get(offset + 4).unwrap(),
        encoded_price_feed.get(offset + 5).unwrap(),
        encoded_price_feed.get(offset + 6).unwrap(),
        encoded_price_feed.get(offset + 7).unwrap(),
    ]);
    offset += 8;

    let ema_confidence = u64::from_be_bytes([
        encoded_price_feed.get(offset).unwrap(),
        encoded_price_feed.get(offset + 1).unwrap(),
        encoded_price_feed.get(offset + 2).unwrap(),
        encoded_price_feed.get(offset + 3).unwrap(),
        encoded_price_feed.get(offset + 4).unwrap(),
        encoded_price_feed.get(offset + 5).unwrap(),
        encoded_price_feed.get(offset + 6).unwrap(),
        encoded_price_feed.get(offset + 7).unwrap(),
    ]);
    offset += 8;

    require(offset <= encoded_price_feed.len, PythError::InvalidUpdateData);

    PriceFeed::new(Price::new(ema_confidence, exponent, ema_price, publish_time), price_feed_id, Price::new(confidence, exponent, price, publish_time))
}

// utils::absolute_of_exponent and pyth_merkle_proof::validate_proof temporarily moved to silence errors while importing from actual libs
fn absolute_of_exponent(exponent: u32) -> u32 {
    if exponent == 0u32 {
        exponent
    } else {
        u32::max() - exponent + 1
    }
}

/// Concatenated to leaf input as described by
/// "MTH({d(0)}) = KECCAK-256(0x00 || d(0))"
pub const LEAF = 0u8;
/// Concatenated to node input as described by
/// "MTH(D[n]) = KECCAK-256(0x01 || MTH(D[0:k]) || MTH(D[k:n]))"
pub const NODE = 1u8;

fn leaf_digest(data: Bytes) -> Bytes {
    let mut bytes = Bytes::new();
    bytes.push(LEAF);
    bytes.append(data);

    let (slice, _) = Bytes::from(bytes.keccak256()).split_at(20);

    slice
}

fn node_digest(left: Bytes, right: Bytes) -> Bytes {
    let mut bytes = Bytes::with_capacity(41);
    bytes.push(NODE);

    let l: b256 = left.into();
    let r: b256 = right.into();
    if l < r {
        bytes.append(left);
        bytes.append(right);
    } else {
        bytes.append(right);
        bytes.append(left);
    }

    let (slice, _) = Bytes::from(bytes.keccak256()).split_at(20);

    slice
}

fn validate_proof(
    encoded_proof: Bytes,
    leaf_data: Bytes,
    ref mut proof_offset: u64,
    root: Bytes,
) -> u64 {
    let mut current_digest = leaf_digest(leaf_data);

    let proof_size = encoded_proof.get(proof_offset).unwrap().as_u64();
    proof_offset += 1;

    let mut i = 0;
    while i < proof_size {
        let (_, slice) = encoded_proof.split_at(proof_offset);
        let (sibling_digest, _) = slice.split_at(20);
        proof_offset += 20;

        current_digest = node_digest(current_digest, sibling_digest);

        i += 1;
    }

    require(current_digest == root, PythError::InvalidProof);

    proof_offset
}
