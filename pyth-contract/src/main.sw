contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod pyth_accumulator;
mod pyth_batch;
mod utils;
mod wormhole_light;

use ::data_structures::{
    data_source::DataSource,
    price::{
        Price,
        PriceFeed,
        PriceFeedId,
    },
    wormhole_light::{
        GuardianSet,
        Provider,
        Signature,
        VM,
    },
};
use ::errors::{PythError};
use ::interface::{PythCore, PythInfo, PythInit, WormholeGuardians};
use ::pyth_accumulator::{
    accumulator_magic_bytes,
    AccumulatorUpdate,
    extract_price_feed_from_merkle_proof,
    parse_wormhole_merkle_header_updates,
};
use ::pyth_batch::{parse_batch_attestation_header, parse_single_attestation_from_batch};
use ::utils::{difference, find_index_of_price_feed_id, update_type, UpdateType};
use ::wormhole_light::{parse_guardian_set_upgrade, parse_vm, UPGRADE_MODULE};

use std::{
    block::timestamp,
    bytes::Bytes,
    call_frames::msg_asset_id,
    constants::{
        BASE_ASSET_ID,
        ZERO_B256,
    },
    context::msg_amount,
    storage::{
        storage_map::StorageMap,
        storage_vec::*,
    },
    u256::U256,
};
use src_5::Ownership;
use ownership::*;

storage {
    owner: Ownership = Ownership::initialized(Identity::Address(Address::from(ZERO_B256))),
    /// PYTH STATE ///
    // (chainId, emitterAddress) => isValid; takes advantage of
    // constant-time mapping lookup for VM verification
    is_valid_data_source: StorageMap<b256, bool> = StorageMap {},
    // Mapping of cached price information
    // priceId => PriceInfo
    latest_price_feed: StorageMap<PriceFeedId, PriceFeed> = StorageMap {},
    single_update_fee_in_wei: u64 = 0,
    // For tracking all active emitter/chain ID pairs
    valid_data_sources: StorageVec<DataSource> = StorageVec {},
    /// Maximum acceptable time period before price is considered to be stale.
    /// This includes attestation delay, block time, and potential clock drift
    /// between the source/target chains.
    valid_time_period_seconds: u64 = 0,
    wormhole_contract_id: ContractId = ContractId {
        value: ZERO_B256,
    },
    ///  WORMHOLE STATE ///
    // Mapping of consumed governance actions
    wormhole_consumed_governance_actions: StorageMap<b256, bool> = StorageMap {},
    // Mapping of guardian_set_index => guardian set
    wormhole_guardian_sets: StorageMap<u32, GuardianSet> = StorageMap {},
    // Current active guardian set index
    wormhole_guardian_set_index: u32 = 0,
}

impl PythCore for Contract {
    #[storage(read)]
    fn ema_price(price_feed_id: PriceFeedId) -> Price {
        ema_price_no_older_than(valid_time_period(), price_feed_id)
    }

    #[storage(read)]
    fn ema_price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price {
        ema_price_no_older_than(time_period, price_feed_id)
    }

    #[storage(read)]
    fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price {
        ema_price_unsafe(price_feed_id)
    }

    #[storage(read), payable]
    fn parse_price_feed_updates(
        max_publish_time: u64,
        min_publish_time: u64,
        price_feed_ids: Vec<PriceFeedId>,
        update_data: Vec<Bytes>,
    ) -> Vec<PriceFeed> {
        require(msg_asset_id() == BASE_ASSET_ID, PythError::FeesCanOnlyBePaidInTheBaseAsset);

        let required_fee = update_fee(update_data);
        require(msg_amount() >= required_fee, PythError::InsufficientFee);

        let mut price_feeds: Vec<PriceFeed> = Vec::with_capacity(price_feed_ids.len);

        let mut index = 0;
        let update_data_length = update_data.len;
        while index < update_data_length {
            let data = update_data.get(index).unwrap();

            match update_type(data) {
                UpdateType::Accumulator(accumulator_update) => {
                    let offset = accumulator_update.verify();

                    let (offset, digest, number_of_updates, encoded) = extract_wormhole_merkle_header_digest_and_num_updates_and_encoded_from_accumulator_update(data, offset);

                    let mut index_2 = 0;
                    while index_2 < number_of_updates {
                        let (_offset, price_feed, price_feed_id) = extract_price_feed_from_merkle_proof(digest, encoded, offset);

                        // check whether caller requested for this data
                        let price_feed_id_index = find_index_of_price_feed_id(price_feed_ids, price_feed_id);

                        // If price_feeds[price_feed_id_index].id != ZERO_B256 then it means that there was a valid
                        // update for price_feed_ids[price_feed_id_index] and we don't need to process this one.
                        if price_feed_id_index == price_feed_ids.len
                            || price_feeds.get(price_feed_id_index).unwrap().id != ZERO_B256
                        {
                            continue;
                        }

                        // Check the publish time of the price is within the given range
                        // and only fill PriceFeed if it is.
                        // If it is not, default id value of 0 will still be set and
                        // this will allow other updates for this price id to be processed.
                        if price_feed.price.publish_time >= min_publish_time
                            && price_feed.price.publish_time <= max_publish_time
                        {
                            price_feeds.push(price_feed)
                        }

                        index_2 += 1;
                    }
                    require(offset == encoded.len, PythError::InvalidUpdateData);
                },
                UpdateType::BatchAttestation => {
                    let vm = parse_and_verify_batch_attestation_VM(data);
                    let encoded_payload = vm.payload;

                    let (
                        mut attestation_index,
                        number_of_attestations,
                        attestation_size,
                    ) = parse_batch_attestation_header(encoded_payload);

                    let mut index_2 = 0;
                    while index_2 < number_of_attestations {
                        //remove prior price attestations and this price attestation's product_id
                        let (_front, back) = encoded_payload.split_at(attestation_index + 32);
                        //extract this price attestation's price_feed_id
                        let (price_feed_id, _back) = back.split_at(32);
                        let price_feed_id: b256 = price_feed_id.into();

                        // check whether caller requested for this data
                        let price_feed_id_index = find_index_of_price_feed_id(price_feed_ids, price_feed_id);

                        // If price_feeds[price_feed_id_index].id != ZERO_B256 then it means that there was a valid
                        // update for price_feed_ids[price_feed_id_index] and we don't need to process this one.
                        if price_feed_id_index == price_feed_ids.len
                            || price_feeds.get(price_feed_id_index).unwrap().id != ZERO_B256
                        {
                            continue;
                        }

                        let price_feed = parse_single_attestation_from_batch(attestation_index, attestation_size, encoded_payload);

                        // Check the publish time of the price is within the given range
                        // and only fill PriceFeed if it is.
                        // If it is not, default id value of 0 will still be set and
                        // this will allow other updates for this price id to be processed.
                        if price_feed.price.publish_time >= min_publish_time
                            && price_feed.price.publish_time <= max_publish_time
                        {
                            price_feeds.push(price_feed)
                        }

                        attestation_index += attestation_size;
                        index_2 += 1;
                    }
                }
            }

            index += 1;
        }

        let mut index_3 = 0;
        let price_feed_ids_length = price_feed_ids.len;
        while index_3 < price_feed_ids_length {
            require(price_feeds.get(index_3).unwrap().id != ZERO_B256, PythError::PriceFeedNotFoundWithinRange);

            index_3 += 1;
        }

        price_feeds
    }

    #[storage(read)]
    fn price(price_feed_id: PriceFeedId) -> Price {
        price_no_older_than(valid_time_period(), price_feed_id)
    }

    #[storage(read)]
    fn price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price {
        price_no_older_than(time_period, price_feed_id)
    }

    #[storage(read)]
    fn price_unsafe(price_feed_id: PriceFeedId) -> Price {
        price_unsafe(price_feed_id)
    }

    #[storage(read)]
    fn update_fee(update_data: Vec<Bytes>) -> u64 {
        update_fee(update_data)
    }

    #[storage(read, write), payable]
    fn update_price_feeds(update_data: Vec<Bytes>) {
        update_price_feeds(update_data)
    }

    #[storage(read, write), payable]
    fn update_price_feeds_if_necessary(
        price_feed_ids: Vec<PriceFeedId>,
        publish_times: Vec<u64>,
        update_data: Vec<Bytes>,
    ) {
        require(price_feed_ids.len == publish_times.len, PythError::InvalidArgument);

        let mut index = 0;
        let price_feed_ids_length = price_feed_ids.len;
        while index < price_feed_ids_length {
            if latest_price_feed_publish_time(price_feed_ids.get(index).unwrap()) < publish_times.get(index).unwrap()
            {
                update_price_feeds(update_data);
                return;
            }

            index += 1;
        }
    }

    #[storage(read)]
    fn valid_time_period() -> u64 {
        valid_time_period()
    }
}

/// PythCore Private Functions ///
#[storage(read)]
fn ema_price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price {
    let price = ema_price_unsafe(price_feed_id);

    require(difference(timestamp(), price.publish_time) <= time_period, PythError::OutdatedPrice);

    price
}

#[storage(read)]
fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price {
    let price_feed = storage.latest_price_feed.get(price_feed_id).try_read();
    require(price_feed.is_some(), PythError::PriceFeedNotFound);

    price_feed.unwrap().ema_price
}

#[storage(read)]
fn price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price {
    let price = price_unsafe(price_feed_id);

    require(difference(timestamp(), price.publish_time) <= time_period, PythError::OutdatedPrice);

    price
}

#[storage(read)]
fn price_unsafe(price_feed_id: PriceFeedId) -> Price {
    let price_feed = storage.latest_price_feed.get(price_feed_id).try_read();
    require(price_feed.is_some(), PythError::PriceFeedNotFound);

    price_feed.unwrap().price
}

#[storage(read)]
fn update_fee(update_data: Vec<Bytes>) -> u64 {
    let mut total_number_of_updates = 0;
    let mut index = 0;
    let update_data_length = update_data.len;

    while index < update_data_length {
        let data = update_data.get(index).unwrap();

        match update_type(data) {
            UpdateType::Accumulator(accumulator_update) => {
                let proof_size_offset = accumulator_update.verify();

                total_number_of_updates += accumulator_update.total_updates(proof_size_offset);
            },
            UpdateType::BatchAttestation => {
                total_number_of_updates += 1;
            },
        }

        index += 1;
    }

    total_fee(total_number_of_updates)
}

#[storage(read, write), payable]
fn update_price_feeds(update_data: Vec<Bytes>) {
    require(msg_asset_id() == BASE_ASSET_ID, PythError::FeesCanOnlyBePaidInTheBaseAsset);

    let mut total_number_of_updates = 0;

    let mut index = 0;
    let update_data_length = update_data.len;
    while index < update_data_length {
        let data = update_data.get(index).unwrap();

        match update_type(data) {
            UpdateType::Accumulator => {
                total_number_of_updates += update_price_feeds_from_accumulator_update(data);
            },
            UpdateType::BatchAttestation => {
                update_price_batch_from_vm(data);
                total_number_of_updates += 1;
            },
        }

        index += 1;
    }

    let required_fee = total_fee(total_number_of_updates);
    require(msg_amount() >= required_fee, PythError::InsufficientFee);
}

#[storage(read)]
fn valid_time_period() -> u64 {
    storage.valid_time_period_seconds.read()
}

impl PythInit for Contract {
    #[storage(read, write)]
    fn initialize(
        wormhole_contract_id: ContractId,
        data_source_emitter_chain_ids: Vec<u16>,
        data_source_emitter_addresses: Vec<b256>,
        governance_emitter_chainId: u16,
        governance_emitter_address: b256,
        governance_initial_sequence: u64,
        valid_time_period_seconds: u64,
        single_update_fee_in_wei: u64,
        wormhole_guardian_set_upgrade: Bytes,
    ) {
        storage.owner.only_owner();

        require(data_source_emitter_chain_ids.len == data_source_emitter_addresses.len, PythError::InvalidArgument);

        storage.wormhole_contract_id.write(wormhole_contract_id);

        let mut index = 0;
        let data_source_emitter_chain_ids_length = data_source_emitter_chain_ids.len;
        while index < data_source_emitter_chain_ids_length {
            let data_source = DataSource::new(data_source_emitter_chain_ids.get(index).unwrap(), data_source_emitter_addresses.get(index).unwrap());

            //TODO uncomment when Hash is included in release
            // storage.is_valid_data_source.insert(data_source.hash(), true);

            storage.valid_data_sources.push(data_source);

            index += 1;
        }

        storage.valid_time_period_seconds.write(valid_time_period_seconds);
        storage.single_update_fee_in_wei.write(single_update_fee_in_wei);

        submit_new_guardian_set(wormhole_guardian_set_upgrade);

        storage.owner.renounce_ownership();
    }
}

impl PythInfo for Contract {
    #[storage(read)]
    fn current_valid_data_sources() -> StorageVec<DataSource> {
        storage.valid_data_sources.read()
    }

    //TODO uncomment when Hash is included in release
    // fn hash_data_source(data_source: DataSource) -> b256 {
    //     data_source.hash()
    // }

    #[storage(read)]
    fn latest_price_feed_publish_time(price_feed_id: PriceFeedId) -> u64 {
        latest_price_feed_publish_time(price_feed_id)
    }

    #[storage(read)]
    fn price_feed_exists(price_feed_id: PriceFeedId) -> bool {
        latest_price_feed_publish_time(price_feed_id) != 0
    }

    #[storage(read)]
    fn query_price_feed(price_feed_id: PriceFeedId) -> PriceFeed {
        let price_feed = storage.latest_price_feed.get(price_feed_id).try_read();
        require(price_feed.is_some(), PythError::PriceFeedNotFound);
        price_feed.unwrap()
    }

    //TODO uncomment when Hash is included in release
    // #[storage(read)]
    // fn valid_data_source(data_source: DataSource) -> bool {
    //     match storage.is_valid_data_source.get(
    //             data_source.hash()
    //         ).try_read() {
    //             Some(bool) => bool,
    //             None => false,
    //         }
    // }
}

/// PythInfo Private Functions ///
#[storage(read)]
fn latest_price_feed_publish_time(price_feed_id: PriceFeedId) -> u64 {
    match storage.latest_price_feed.get(price_feed_id).try_read() {
        Some(price_feed) => price_feed.price.publish_time,
        None => 0,
    }
}

#[storage(read)]
fn verify_governance_vm(vm: VM) {
    //PLACEHOLDER
}

impl WormholeGuardians for Contract {
    #[storage(read)]
    fn governance_action_is_consumed(hash: b256) -> bool {
        let consumed = storage.wormhole_consumed_governance_actions.get(hash).try_read();
        require(consumed.is_some(), PythError::WormholeGovernanceActionNotFound);
        consumed.unwrap()
    }

    #[storage(read)]
    fn guardian_set(index: u32) -> GuardianSet {
        let guardian_set = storage.wormhole_guardian_sets.get(index).try_read();
        require(guardian_set.is_some(), PythError::GuardianSetNotFound);
        guardian_set.unwrap()
    }

    #[storage(read)]
    fn current_guardian_set_index() -> u32 {
        current_guardian_set_index()
    }

    #[storage(read, write)]
    fn submit_new_guardian_set(encoded_vm: Bytes) {
        submit_new_guardian_set(encoded_vm)
    }
}

/// WormholeGuardians Private Functions ///
#[storage(read)]
fn current_guardian_set_index() -> u32 {
    storage.wormhole_guardian_set_index.read()
}

#[storage(read, write)]
fn submit_new_guardian_set(encoded_vm: Bytes) {
    let vm = parse_vm(encoded_vm);

    verify_governance_vm(vm);

    let upgrade = parse_guardian_set_upgrade(vm.payload);
    require(upgrade.module == UPGRADE_MODULE, PythError::InvalidUpgradeModule);
    require(upgrade.new_guardian_set.keys.len() > 0, PythError::NewGuardianSetIsEmpty);
    let current_guardian_set_index = current_guardian_set_index();
    require(upgrade.new_guardian_set_index > current_guardian_set_index, PythError::NewGuardianSetIndexIsInvalid);

    storage.wormhole_consumed_governance_actions.insert(vm.hash, true);

    // Set expiry if Guardian set exists
    let current_guardian_set = storage.wormhole_guardian_sets.get(current_guardian_set_index).try_read();
    if current_guardian_set.is_some() {
        let mut current_guardian_set = current_guardian_set.unwrap();
        current_guardian_set.expiration_time = timestamp() + 86400u64;
        storage.wormhole_guardian_sets.insert(current_guardian_set_index, current_guardian_set);
    }

    storage.wormhole_guardian_sets.insert(upgrade.new_guardian_set_index, upgrade.new_guardian_set);
    storage.wormhole_guardian_set_index.write(upgrade.new_guardian_set_index);
}

/// General Private Functions ///
#[storage(read)]
fn total_fee(total_number_of_updates: u64) -> u64 {
    total_number_of_updates * storage.single_update_fee_in_wei.read()
}

/// Pyth-accumulator Private Functions ///
#[storage(read)]
fn parse_and_verify_pyth_VM(encoded_vm: Bytes) -> VM {
    let vm = parse_and_verify_wormhole_VM(encoded_vm);

    require(
        valid_data_source(DataSource::new(
            vm.emitter_chain_id 
            vm.emitter_address
        ))
    ,PythError::InvalidUpdateDataSource
    );

    vm
}

#[storage(read)]
fn extract_wormhole_merkle_header_digest_and_num_updates_and_encoded_from_accumulator_update(
    accumulator_update: Bytes,
    encoded_offset: u64,
) -> (u64, Bytes, u64, Bytes) {
    let (_, back) = accumulator_update.split_at(encoded_offset);
    let (encoded_slice, _) = back.split_at(accumulator_update.len - encoded_offset);

    let mut offset = 0;

    //two bytes starting at offset
    let proof_size = u16::from_be_bytes([
        encoded_slice.get(offset).unwrap(),
        encoded_slice.get(offset + 1).unwrap(),
    ]).as_u64();
    offset += 2;

    let vm = parse_and_verify_pyth_VM();
}

#[storage(read, write)]
fn update_price_feeds_from_accumulator_update(accumulator_update: AccumulatorUpdate) -> u64 {
    let encoded_offset = accumulator_update.verify();

    let (offset, digest, number_of_updates, encoded_data) = extract_wormhole_merkle_header_digest_and_num_updates_and_encoded_from_accumulator_update(accumulator_update.data, encoded_offset);
}

/// Pyth-batch-price Private Functions ///
#[storage(read)]
fn parse_and_verify_batch_attestation_VM(encoded_vm: Bytes) -> VM {
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

#[storage(read, write)]
fn update_price_batch_from_vm(encoded_vm: Bytes) {
    //PLACEHOLDER 
}

/// Wormhole light Private Functions ///
#[storage(read)]
fn parse_and_verify_wormhole_VM(encoded_vm: Bytes) -> VM {
    let mut index = 0;

    let mut vm = VM::default();

    let version = encoded_vm.get(index);
    require(version.is_some() && version.unwrap() == 1, WormholeError::VmVersionIncompatible);
    index += 1;

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(4); //replace with slice()
    let guardian_set_index = u32::from_be_bytes([ //replace with func
            slice.get(0).unwrap(),
            slice.get(1).unwrap(),
            slice.get(2).unwrap(),
            slice.get(3).unwrap(),
        ]);
    index += 4;

    let guardian_set = storage.wormhole_guardian_sets.get(guardian_set_index).try_read();
    require(guardian_set.is_some(), WormholeError::GuardianSetNotFound);
    let guardian_set = guardian_set.unwrap();
    require(guardian_set.keys.len() > 0, WormholeError::InvalidGuardianSet);
    require(guardian_set_index == current_guardian_set_index() && guardian_set.expiration_time > timestamp(), WormholeError::InvalidGuardianSet);

    let signers_length = encoded_vm.get(index);
    require(signers_length.is_some(), WormholeError::SignersLengthIrretrievable);
    let signers_length = signers_length.unwrap();
    index += 1;

    // 66 is the length of each guardian signature
    // 1 (guardianIndex) + 32 (r) + 32 (s) + 1 (v)
    let hash_index = index + (signers_length * 66);
    require(hash_index < encoded_vm.len, WormholeError::InvalidSignatureLength);

    let (_, slice) = encoded_vm.split_at(hash_index);
    let hash = slice.keccak256().keccak256();

    let mut last_index = 0;
    let mut i = 0;
    while i < signers_length {
        let guardian_index = encoded_vm.get(index);
        require(guardian_index.is_some(), WormholeError::GuardianIndexIrretrievable);
        let guardian_index = guardian_index.unwrap();
        index += 1;

        let (_, slice) = encoded_vm.split_at(index);
        let (slice, remainder) = slice.split_at(32);
        let r: b256 = slice.into();
        index += 32;

        let (slice, remainder) = remainder.split_at(32); 
        let s: b256 = slice.into();
        index += 32;

        let v = remainder.get(0);
        require(v.is_some(), WormholeError::SignatureVIrretrievable);
        let v = v.unwrap() + 27;
        index += 1;

        let guardian_set_key = guardian_set.keys.get(guardian_index);
        require(guardian_set_key.is_some(), WormholeError::GuardianSetKeyIrretrievable);
  
        GuardianSignature::new(guardian_index,r,s,v)
        .verify(guardian_set_key.unwrap(), hash, i, last_index);

        last_index = guardian_index;
        i += 1;
    }

    /*
    We're using a fixed point number transformation with 1 decimal to deal with rounding.
    This quorum check is critical to assessing whether we have enough Guardian signatures to validate a VM.
    If guardian set key length is 0 and signatures length is 0, this could compromise the integrity of both VM and signature verification.
    */
    require(
        ((((guardian_set.keys.len() * 10) / 3) * 2) / 10 + 1) <= signers_length
        , WormholeError::NoQuorum
    );

    //ignore VM.signatures

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(4);
    let timestamp = u32::from_be_bytes([
            slice.get(0).unwrap(),
            slice.get(1).unwrap(),
            slice.get(2).unwrap(),
            slice.get(3).unwrap(),
        ]);
    index += 4;

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(4);
    let nonce = u32::from_be_bytes([
            slice.get(0).unwrap(),
            slice.get(1).unwrap(),
            slice.get(2).unwrap(),
            slice.get(3).unwrap(),
        ]);
    index += 4;

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(2);
    let emitter_chain_id = u16::from_be_bytes([
            slice.get(0).unwrap(),
            slice.get(1).unwrap(),
        ]);
    index += 2;

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(32);
    let emitter_address: b256 = slice.into();
    index += 32;

    let (_, slice) = encoded_vm.split_at(index);
    let (slice, _) = slice.split_at(8);
    let sequence = u64::from_be_bytes([
            slice.get(0).unwrap(),
            slice.get(1).unwrap(),
            slice.get(2).unwrap(),
            slice.get(3).unwrap(),
            slice.get(4).unwrap(),
            slice.get(5).unwrap(),
            slice.get(6).unwrap(),
            slice.get(7).unwrap(),
        ]);
    index += 8;

    let consistency_level = encoded_vm.get(index);
    require(consistency_level.is_some(), WormholeError::VMConsistencyLevelIrretrievable);
    index += 1;

    require(index <= encoded_vm.len, WormholeError::InvalidPayloadLength);

    let payload = let (_, slice) = encoded_vm.split_at(index);

    VM::new(
        version,
        guardian_set_index,
        hash,
        timestamp,
        nonce,
        emitter_chain_id,
        emitter_address,
        sequence,
        consistency_level,
        payload,
    )
}