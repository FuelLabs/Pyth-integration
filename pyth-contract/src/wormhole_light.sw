library;

use ::data_structures::wormhole_light::{
    GuardianSet,
    GuardianSetUpgrade,
    GuardianSignature,
    Provider,
    WormholeVM,
};
use ::errors::{WormholeError};
use std::{
    b512::B512,
    bytes::Bytes,
    constants::{
        BASE_ASSET_ID,
        ZERO_B256,
    },
    hash::sha256,
    storage::storage_vec::*,
    vm::evm::ecr::ec_recover_evm_address,
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

// Notes: impl here as difficulties were encountered using errors from within data_structures
impl GuardianSignature {
    pub fn new(guardian_index: u8, r: b256, s: b256, v: u8) -> self {
        GuardianSignature {
            guardian_index,
            r,
            s,
            v,
        }
    }

    // eip-2098: Compact Signature Representation
    fn compact(self) -> B512 {
        let y_parity = b256::from_be_bytes([
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            self.v,
        ]);
        let shifted_y_parity = y_parity.lsh(255);
        // let y_parity_and_s = shifted_y_parity.binary_or(self.s);
        let y_parity_and_s = b256::binary_or(shifted_y_parity, self.s);

        B512::from((self.r, y_parity_and_s))
    }
}

impl GuardianSignature {
    pub fn verify(
        self,
        guardian_set_key: b256,
        hash: b256,
        index: u64,
        last_index: u64,
) {
        // Ensure that provided signature indices are ascending only
        if index > 0 {
            require(self.guardian_index.as_u64() > last_index, WormholeError::SignatureIndicesNotAscending);
        }

        let recovered_signer = ec_recover_evm_address(self.compact(), hash);
        require(recovered_signer.is_ok() && recovered_signer.unwrap().value == guardian_set_key, WormholeError::VMSignatureInvalid);
    }
}
