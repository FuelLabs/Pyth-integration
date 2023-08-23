library;

//TODO uncomment when Hash is included in release
// use std::hash::Hasher;
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

    //TODO uncomment when Hash is included in release
    //    pub fn hash (self) -> b256 { 
    //     let mut hasher = Hasher::new();
    //     self.chain_id.hash(hasher);
    //     self.emitter_address.hash(hasher);
    //     hasher.keccak256()
    //    }
}
