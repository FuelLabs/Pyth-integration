library;

use ::pyth_accumulator::{accumulator_magic_bytes, AccumulatorUpdate};

use std::bytes::Bytes;

pub enum UpdateType {
    Accumulator: AccumulatorUpdate,
    BatchAttestation: (),
}

pub fn update_type(data: Bytes) -> UpdateType {
    let (magic, _) = data.split_at(4);
    if data.len > 4 && magic == accumulator_magic_bytes() {
        UpdateType::Accumulator(AccumulatorUpdate::new(data))
    } else {
        UpdateType::BatchAttestation
    }
}
