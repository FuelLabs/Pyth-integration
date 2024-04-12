library;

use ::errors::WormholeError;
use std::{
    array_conversions::{
        u16::*,
        u32::*,
    },
    b512::B512,
    bytes::Bytes,
    constants::ZERO_B256,
    hash::{
        Hash,
        sha256,
    },
    storage::storage_vec::*,
};

pub const UPGRADE_MODULE: b256 = 0x00000000000000000000000000000000000000000000000000000000436f7265;

pub struct GuardianSet {
    pub expiration_time: u64,
    pub keys: Vec<b256>,
}

impl GuardianSet {
    #[storage(read)]
    pub fn from_stored(stored: StorageGuardianSet) -> Self {
        Self {
            expiration_time: stored.expiration_time,
            keys: stored.keys.load_vec(),
        }
    }
}

pub struct StorageGuardianSet {
    pub expiration_time: u64,
    pub keys: StorageKey<StorageVec<b256>>,
}

impl StorageGuardianSet {
    pub fn new(expiration_time: u64, keys: StorageKey<StorageVec<b256>>) -> Self {
        StorageGuardianSet {
            expiration_time,
            keys,
        }
    }
}

pub struct GuardianSetUpgrade {
    pub action: u8,
    pub chain: u16,
    pub module: b256,
    pub new_guardian_set: StorageGuardianSet,
    pub new_guardian_set_index: u32,
}

impl GuardianSetUpgrade {
    pub fn new(
        action: u8,
        chain: u16,
        module: b256,
        new_guardian_set: StorageGuardianSet,
        new_guardian_set_index: u32,
    ) -> Self {
        GuardianSetUpgrade {
            action,
            chain,
            module,
            new_guardian_set,
            new_guardian_set_index,
        }
    }

    #[storage(read, write)]
    pub fn parse_encoded_upgrade(current_guardian_set_index: u32, encoded_upgrade: Bytes) -> Self {
        let mut index = 0;
        let (_, slice) = encoded_upgrade.split_at(index);
        let (module, _) = slice.split_at(32);
        let module: b256 = module.into();
        require(module == UPGRADE_MODULE, WormholeError::InvalidModule);
        index += 32;
        let action = encoded_upgrade.get(index).unwrap();
        require(action == 2, WormholeError::InvalidGovernanceAction);
        index += 1;
        let chain = u16::from_be_bytes([encoded_upgrade.get(index).unwrap(), encoded_upgrade.get(index + 1).unwrap()]);
        index += 2;
        let new_guardian_set_index = u32::from_be_bytes([
            encoded_upgrade.get(index).unwrap(),
            encoded_upgrade.get(index + 1).unwrap(),
            encoded_upgrade.get(index + 2).unwrap(),
            encoded_upgrade.get(index + 3).unwrap(),
        ]);
        require(
            new_guardian_set_index > current_guardian_set_index,
            WormholeError::NewGuardianSetIndexIsInvalid,
        );
        index += 4;
        let guardian_length = encoded_upgrade.get(index).unwrap();
        index += 1;
        let mut new_guardian_set = StorageGuardianSet::new(
            0,
            StorageKey::<StorageVec<b256>>::new(
                sha256(("guardian_set_keys", new_guardian_set_index)),
                0,
                ZERO_B256,
            ),
        );
        let mut i: u8 = 0;
        while i < guardian_length {
            let (_, slice) = encoded_upgrade.split_at(index);
            let (key, _) = slice.split_at(20);
            let key: b256 = key.into();
            new_guardian_set.keys.push(key.rsh(96));
            index += 20;
            i += 1;
        }
        require(
            new_guardian_set
                .keys
                .len() > 0,
            WormholeError::NewGuardianSetIsEmpty,
        );
        require(
            encoded_upgrade
                .len() == index,
            WormholeError::InvalidGuardianSetUpgradeLength,
        );
        GuardianSetUpgrade::new(
            action,
            chain,
            module,
            new_guardian_set,
            new_guardian_set_index,
        )
    }
}
