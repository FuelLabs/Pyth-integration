library;

use std::{bytes::Bytes, storage::storage_vec::*};

pub struct GuardianSet {
    expiration_time: u64,
    keys: StorageKey<StorageVec<b256>>,
}

pub struct GuardianSetUpgrade {
    action: u8,
    chain: u16,
    module: b256,
    new_guardian_set: GuardianSet,
    new_guardian_set_index: u32,
}

pub struct Provider {
    chain_id: u16,
    governance_chain_id: u16,
    governance_contract: b256,
}

pub struct Signature {
    r: b256,
    s: b256,
    v: u8,
    guardian_index: u8,
}

pub struct VM {
    version: u8,
    timestamp: u32,
    nonce: u32,
    emitter_chain_id: u16,
    emitter_address: b256,
    sequence: u64,
    consistency_level: u8,
    payload: Bytes,
    guardian_set_index: u32,
    signatures: Vec<Signature>,
    hash: b256,
}
