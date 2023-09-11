contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod utils;
mod pyth_merkle_proof;

use ::data_structures::{
    data_source::DataSource,
    price::{
        Price,
        PriceFeed,
        PriceFeedId,
    },
    wormhole_light::{
        GuardianSet,
        GuardianSignature,
        WormholeProvider,
        WormholeVM,
    },
};
use ::errors::{PythError, WormholeError};
use ::interface::{PythCore, PythInfo, PythInit, WormholeGuardians};
use ::utils::{difference};

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

// Set before deployment
const DEPLOYER: b256 = ZERO_B256;

storage {
    deployer: Ownership = Ownership::initialized(Identity::Address(Address::from(DEPLOYER))),

    /// PYTH STATE ///
    // (chainId, emitterAddress) => isValid; takes advantage of
    // constant-time mapping lookup for VM verification
    is_valid_data_source: StorageMap<DataSource, bool> = StorageMap {},
    // Mapping of cached price information
    // priceId => PriceInfo
    latest_price_feed: StorageMap<PriceFeedId, PriceFeed> = StorageMap {},
    single_update_fee: u64 = 0,
    // For tracking all active emitter/chain ID pairs
    valid_data_sources: StorageVec<DataSource> = StorageVec {},
    /// Maximum acceptable time period before price is considered to be stale.
    /// This includes attestation delay, block time, and potential clock drift
    /// between the source/target chains.
    valid_time_period_seconds: u64 = 0,
    
    ///  WORMHOLE STATE ///
    // Mapping of consumed governance actions
    wormhole_consumed_governance_actions: StorageMap<b256, bool> = StorageMap {},
    // Mapping of guardian_set_index => guardian set
    wormhole_guardian_sets: StorageMap<u32, GuardianSet> = StorageMap {},
    // Current active guardian set index
    wormhole_guardian_set_index: u32 = 0,
    // Using Ethereum's Wormhole governance
    wormhole_provider: WormholeProvider = WormholeProvider {
        chain_id: 0u16,
        governance_chain_id: 0u16,
        governance_contract: ZERO_B256,
    },
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
        target_price_feed_ids: Vec<PriceFeedId>,
        update_data: Vec<Bytes>,
    ) -> Vec<PriceFeed> {
        require(msg_asset_id() == BASE_ASSET_ID, PythError::FeesCanOnlyBePaidInTheBaseAsset);

        let required_fee = update_fee(update_data);
        require(msg_amount() >= required_fee, PythError::InsufficientFee);

        let mut output_price_feeds: Vec<PriceFeed> = Vec::with_capacity(target_price_feed_ids.len);
        let mut i = 0;
        while i < update_data.len {
            let data = update_data.get(i).unwrap();

            match update_type(data) {
                UpdateType::Accumulator(accumulator_update) => {

                    let (mut offset, digest, number_of_updates, encoded) = verify_and_parse(accumulator_update, storage.wormhole_guardian_sets);

                    let mut i_2 = 0;
                    while i_2 < number_of_updates {
                        let (new_offset, price_feed) = PriceFeed::extract_from_merkle_proof(digest,encoded,offset);

                        offset = new_offset;

                        if price_feed.id.is_target(target_price_feed_ids) == false
                        {
                            continue;
                        }

                        if price_feed.price.publish_time >= min_publish_time && price_feed.price.publish_time <= max_publish_time {
                            // check if output_price_feeds already contains a PriceFeed with price_feed.id, if so continue as we only want 1 
                            // output PriceFeed per target ID
                            if price_feed.id.is_contained_within(output_price_feeds)
                            {
                                continue;
                            }

                            output_price_feeds.push(price_feed)
                        }

                        i_2 += 1;
                    }
                    require(offset == encoded.len, PythError::InvalidUpdateData);
                },
                UpdateType::BatchAttestation(batch_attestation_update) => {
                    let vm = WormholeVM::parse_and_verify_pyth_vm(batch_attestation_update.data, storage.wormhole_guardian_sets);

                    let (
                        mut attestation_index,
                        number_of_attestations,
                        attestation_size,
                    ) = parse_and_verify_batch_attestation_header(vm.payload);

                    let mut i_2: u16 = 0;
                    while i_2 < number_of_attestations {
                        let (_, slice) = vm.payload.split_at(attestation_index + 32);
                        let (price_feed_id, _) = slice.split_at(32);
                        let price_feed_id: PriceFeedId = price_feed_id.into();

                        if price_feed_id.is_target(target_price_feed_ids) == false
                        {
                            continue;
                        }

                        let price_feed = PriceFeed::parse_attestation(attestation_size, vm.payload, attestation_index);

                        if price_feed.price.publish_time >= min_publish_time && price_feed.price.publish_time <= max_publish_time {
                            // check if output_price_feeds already contains a PriceFeed with price_feed.id, if so continue; 
                            // as we only want 1 output PriceFeed per target ID
                            if price_feed.id.is_contained_within(output_price_feeds)
                            {
                                continue;
                            }

                            output_price_feeds.push(price_feed)
                        }

                        attestation_index += attestation_size.as_u64();
                        i_2 += 1;
                    }
                }
            }

            i += 1;
        }

        require(target_price_feed_ids.len == output_price_feeds.len, PythError::PriceFeedNotFoundWithinRange);

        output_price_feeds
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
            if latest_publish_time(price_feed_ids.get(index).unwrap()) < publish_times.get(index).unwrap()
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

    total_fee(total_number_of_updates, storage.single_update_fee)
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
            UpdateType::Accumulator(accumulator_update) => {
                // updated_price_feeds is for use in logging
                let (number_of_updates, _updated_price_feeds) = accumulator_update.update_price_feeds(storage.wormhole_guardian_sets, storage.latest_price_feed);
                total_number_of_updates += number_of_updates;
            },
            UpdateType::BatchAttestation(batch_attestation_update) => {
                // updated_price_feeds is for use in logging
                let _updated_price_feeds = batch_attestation_update.update_price_feeds(storage.wormhole_guardian_sets, storage.latest_price_feed);

                total_number_of_updates += 1;
            },
        }

        index += 1;
    }

    let required_fee = total_fee(total_number_of_updates, storage.single_update_fee);
    require(msg_amount() >= required_fee, PythError::InsufficientFee);

    //log updated price feed event. A vec of updateeventtype (accumualator(updated_price_feeds), batch(vm.emitterChainId, vm.sequence,updated_price_feeds))
}

#[storage(read)]
fn valid_time_period() -> u64 {
    storage.valid_time_period_seconds.read()
}

impl PythInit for Contract {
    #[storage(read, write)]
    fn constructor(
        data_sources: Vec<DataSource>,
        single_update_fee: u64,
        valid_time_period_seconds: u64,
        wormhole_guardian_set_upgrade: Bytes,
        wormhole_provider: WormholeProvider,
    ) {
        storage.deployer.only_owner();

        let mut i = 0;
        while i < data_sources.len {
            let data_source = data_sources.get(i).unwrap();
            storage.is_valid_data_source.insert(data_source, true);
            storage.valid_data_sources.push(data_source);

            i += 1;
        }

        storage.valid_time_period_seconds.write(valid_time_period_seconds);
        storage.single_update_fee.write(single_update_fee);

        submit_new_guardian_set(wormhole_guardian_set_upgrade);

        storage.wormhole_provider.write(wormhole_provider);

        storage.deployer.renounce_ownership();
    }
}

impl PythInfo for Contract {
    #[storage(read)]
    fn valid_data_sources() -> StorageVec<DataSource> {
        storage.valid_data_sources.read()
    }

    #[storage(read)]
    fn latest_publish_time(price_feed_id: PriceFeedId) -> u64 {
        latest_publish_time(price_feed_id)
    }

    #[storage(read)]
    fn price_feed_exists(price_feed_id: PriceFeedId) -> bool {
        match storage.latest_price_feed.get(price_feed_id).try_read() {
            Some(_) => true,
            None => false,
        }
    }

    #[storage(read)]
    fn price_feed(price_feed_id: PriceFeedId) -> PriceFeed {
        let price_feed = storage.latest_price_feed.get(price_feed_id).try_read();
        require(price_feed.is_some(), PythError::PriceFeedNotFound);
        price_feed.unwrap()
    }

    #[storage(read)]
    fn valid_data_source(data_source: DataSource) -> bool {
        match storage.is_valid_data_source.get(data_source).try_read() {
            Some(bool) => bool,
            None => false,
        }
    }
}

/// PythInfo Private Functions ///
#[storage(read)]
fn latest_publish_time(price_feed_id: PriceFeedId) -> u64 {
    match storage.latest_price_feed.get(price_feed_id).try_read() {
        Some(price_feed) => price_feed.price.publish_time,
        None => 0,
    }
}

impl WormholeGuardians for Contract {
    #[storage(read)]
    fn current_guardian_set_index() -> u32 {
        current_guardian_set_index()
    }

    #[storage(read)]
    fn current_wormhole_provider() -> WormholeProvider {
        current_wormhole_provider()
    }

    #[storage(read)]
    fn guardian_set(index: u32) -> GuardianSet {
        let guardian_set = storage.wormhole_guardian_sets.get(index).try_read();
        require(guardian_set.is_some(), PythError::GuardianSetNotFound);
        guardian_set.unwrap()
    }

    #[storage(read)]
    fn governance_action_is_consumed(governance_action_hash: b256) -> bool {
        governance_action_is_consumed(governance_action_hash)
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

#[storage(read)]
fn current_wormhole_provider() -> WormholeProvider {
    storage.wormhole_provider.read()
}

#[storage(read)]
fn governance_action_is_consumed(governance_action_hash: b256) -> bool {
    match storage.wormhole_consumed_governance_actions.get(governance_action_hash).try_read() {
        Some(bool_) => bool_,
        None => false,
    }
}

#[storage(read, write)]
fn submit_new_guardian_set(encoded_vm: Bytes) {
    let vm = WormholeVM::parse_and_verify_wormhole_vm(encoded_vm, storage.wormhole_guardian_sets);
    require(vm.guardian_set_index == current_guardian_set_index(), WormholeError::NotSignedByCurrentGuardianSet);
    let current_wormhole_provider = current_wormhole_provider();
    require(vm.emitter_chain_id == current_wormhole_provider.governance_chain_id, WormholeError::InvalidGovernanceChain);
    require(vm.emitter_address == current_wormhole_provider.governance_contract, WormholeError::InvalidGovernanceContract);
    require(governance_action_is_consumed(vm.governance_action_hash) == false, WormholeError::GovernanceActionAlreadyConsumed);

    let current_guardian_set_index = current_guardian_set_index();
    let upgrade = GuardianSetUpgrade::parse_encoded_upgrade(current_guardian_set_index, vm.payload);

    storage.wormhole_consumed_governance_actions.insert(vm.governance_action_hash, true);

    // Set expiry if current GuardianSet exists
    let current_guardian_set = storage.wormhole_guardian_sets.get(current_guardian_set_index).try_read();
    if current_guardian_set.is_some() {
        let mut current_guardian_set = current_guardian_set.unwrap();
        current_guardian_set.expiration_time = timestamp() + 86400;
        storage.wormhole_guardian_sets.insert(current_guardian_set_index, current_guardian_set);
    }

    storage.wormhole_guardian_sets.insert(upgrade.new_guardian_set_index, upgrade.new_guardian_set);
    storage.wormhole_guardian_set_index.write(upgrade.new_guardian_set_index);
}