library;

use ::data_structures::wormhole_light::{GuardianSet, GuardianSetUpgrade, Provider, Signature, VM};

use std::{
    bytes::Bytes,
    constants::{
        BASE_ASSET_ID,
        ZERO_B256,
    },
    hash::sha256,
    storage::storage_vec::*,
};

pub const UPGRADE_MODULE: b256 = 0x00000000000000000000000000000000000000000000000000000000436f7265;

pub fn parse_guardian_set_upgrade(encoded_upgrade: Bytes) -> GuardianSetUpgrade {
    //PLACEHOLDER
    let guardian_set_index = 0;
    let guardian_set = GuardianSet {
        expiration_time: 0u64,
        keys: StorageKey {
            slot: sha256(("guardian_set_keys", guardian_set_index)),
            offset: 0,
            field_id: ZERO_B256,
        },
    };
    GuardianSetUpgrade {
        action: 0u8,
        chain: 0u16,
        module: ZERO_B256,
        new_guardian_set: guardian_set,
        new_guardian_set_index: 0u32,
    }
}

pub fn parse_vm(encoded_vm: Bytes) -> VM {
    //PLACEHOLDER 
    let mut signatures = Vec::new();
    signatures.push(Signature {
        r: ZERO_B256,
        s: ZERO_B256,
        v: 1u8,
        guardian_index: 1u8,
    });
    VM {
        version: 1u8,
        timestamp: 1u32,
        nonce: 1u32,
        emitter_chain_id: 1u16,
        emitter_address: ZERO_B256,
        sequence: 1u64,
        consistency_level: 1u8,
        payload: Bytes::new(),
        guardian_set_index: 1u32,
        signatures,
        hash: ZERO_B256,
    }
}
