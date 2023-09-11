library;

use std::{block::timestamp};

pub struct DataSource {
    chain_id: u16,
    emitter_address: b256,
}

impl DataSource {
    pub fn new(chain_id: u16, emitter_address: b256) -> Self {
        Self {
            chain_id,
            emitter_address,
        }
    }
}
