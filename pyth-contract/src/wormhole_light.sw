library;

use ::data_structures::wormhole_light::{
    GuardianSet,
    GuardianSetUpgrade,
    GuardianSignature,
    WormholeProvider,
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

#[storage(read, write)]
pub fn parse_guardian_set_upgrade( // impl for GuardianSetUpgrade
    current_guardian_set_index: u32,
    encoded_upgrade: Bytes,
) -> GuardianSetUpgrade {
    let mut index = 0;

    let (_, slice) = encoded_upgrade.split_at(index);
    let (module, _) = slice.split_at(32);
    let module: b256 = module.into();
    require(module == UPGRADE_MODULE, "invalid Module");
    index += 32;

    let action = encoded_upgrade.get(index).unwrap();
    require(action == 2, WormholeError::InvalidGuardianSetUpgrade);
    index += 1;

    let chain = u16::from_be_bytes([
        encoded_upgrade.get(index).unwrap(),
        encoded_upgrade.get(index + 1).unwrap(),
    ]);
    index += 2;

    let new_guardian_set_index = u32::from_be_bytes([
        encoded_upgrade.get(index).unwrap(),
        encoded_upgrade.get(index + 1).unwrap(),
        encoded_upgrade.get(index + 2).unwrap(),
        encoded_upgrade.get(index + 3).unwrap(),
    ]);
    require(new_guardian_set_index > current_guardian_set_index, WormholeError::NewGuardianSetIndexIsInvalid);
    index += 4;

    let guardian_length = encoded_upgrade.get(index).unwrap();
    index += 1;

    let mut new_guardian_set = GuardianSet::new(0, StorageKey {
        slot: sha256(("guardian_set_keys", new_guardian_set_index)),
        offset: 0,
        field_id: ZERO_B256,
    });

    let mut i: u8 = 0;
    while i < guardian_length {
        let (_, slice) = encoded_upgrade.split_at(index);
        let (key, _) = slice.split_at(20);
        let key: b256 = key.into();

        new_guardian_set.keys.push(key);

        index += 20;
        i += 1;
    }

    require(new_guardian_set.keys.len() > 0, WormholeError::NewGuardianSetIsEmpty);
    require(encoded_upgrade.len == index, WormholeError::InvalidGuardianSetUpgrade);

    GuardianSetUpgrade::new(action, chain, module, new_guardian_set, new_guardian_set_index)
}

// Notes: impl here as difficulties were encountered using errors from within data_structures
// moved to data structures
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
