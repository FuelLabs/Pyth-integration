contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod pyth_accumulator;
mod pyth_batch;
mod utils;

use ::data_structures::{
    data_source::DataSource,
    price::{
        Price,
        PriceFeed,
        PriceFeedId,
    },
    pyth_accumulator::AccumulatorUpdateType,
    update_type::UpdateType,
    wormhole::{
        GuardianSet,
        Provider,
        Signature,
        VM,
    },
};
use ::errors::{PythError};
use ::interface::{IPyth, PythGetters, PythSetters};
use ::pyth_accumulator::{
    ACCUMULATOR_MAGIC,
    accumulator_magic_bytes,
    extract_price_feed_from_merkle_proof,
    extract_update_type_from_accumulator_header,
    parse_wormhole_merkle_header_updates,
};
use ::pyth_batch::{parse_batch_attestation_header, parse_single_attestation_from_batch};
use ::utils::{difference, find_index_of_price_feed_id, update_type};

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
    //////////////////
    /// PYTH STATE ///
    //////////////////

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
    ///////////////////////
    ///  WORMHOLE STATE ///
    ///////////////////////

    // Mapping of consumed governance actions
    consumed_governance_actions: StorageMap<b256, bool> = StorageMap {},
    // Mapping of guardian_set_index => guardian set
    guardian_sets: StorageMap<u32, GuardianSet> = StorageMap {},
    // Period for which a guardian set stays active after it has been replaced
    guardian_set_expiry: u32 = 0,
    // Current active guardian set index
    guardian_set_index: u32 = 0,
    // Mapping of initialized implementations
    initialized_implementations: StorageMap<b256, bool> = StorageMap {},
    //
    message_fee: u64 = 0,
    //
    provider: Provider = Provider {
        chain_id: 0,
        governance_chain_id: 0,
        governance_contract: ZERO_B256,
    },
    // Sequence numbers per emitter
    sequences: StorageMap<b256, u64> = StorageMap {},
}

impl IPyth for Contract {
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
        require(msg_asset_id() == BASE_ASSET_ID, PythError::FeesCanOnlyBePayedInTheBaseAsset);

        let required_fee = update_fee(update_data);
        require(msg_amount() >= required_fee, PythError::InsufficientFee);

        let mut price_feeds: Vec<PriceFeed> = Vec::with_capacity(price_feed_ids.len);

        let mut index = 0;
        let update_data_length = update_data.len;
        while index < update_data_length {
            let data = update_data.get(index).unwrap();

            match update_type(data) {
                UpdateType::Accumulator => {
                    let (offset, _update_type) = extract_update_type_from_accumulator_header(data);

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

impl PythSetters for Contract {
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
    ) {
        storage.owner.only_owner();

        require(data_source_emitter_chain_ids.len == data_source_emitter_addresses.len, PythError::InvalidArgument);

        storage.wormhole_contract_id.write(wormhole_contract_id);

        let mut index = 0;
        let data_source_emitter_chain_ids_length = data_source_emitter_chain_ids.len;
        while index < data_source_emitter_chain_ids_length {
            let data_source = DataSource::new(data_source_emitter_chain_ids.get(index).unwrap(), data_source_emitter_addresses.get(index).unwrap());

            // NOTE: Unsure if necessary, but present in the Solidity version. Is it possible to be anything other than false upon deployment
            // require(valid_data_source(data_source.chain_id, data_source.emitter_address) == false, PythErrors::InvalidArgument);

            //TODO uncomment when Hash is included in release
            // storage.is_valid_data_source.insert(data_source.hash(), true);

            storage.valid_data_sources.push(data_source);

            index += 1;
        }
        // TODO: implement/ refactor with governance module
        // let governance_data_source = DataSource::new(governance_emitter_chainId, governance_emitter_address);
        // set_governance_data_source(governance_data_source);
        // set_last_executed_governance_sequence(governance_initial_sequence);

        storage.valid_time_period_seconds.write(valid_time_period_seconds);
        storage.single_update_fee_in_wei.write(single_update_fee_in_wei);

        storage.owner.renounce_ownership();
    }
}

impl PythGetters for Contract {
    #[storage(read)]
    fn chain_id() -> u16 {
        storage.provider.read().chain_id
    }

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
        latest_price_feed_publish_time(price_feed_id) != 0 //replaced
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

///////////////////////////////
/// IPYTH PRIVATE FUNCTIONS ///
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
            UpdateType::Accumulator => {
                let (offset, _update_type) = extract_update_type_from_accumulator_header(data);

                total_number_of_updates += parse_wormhole_merkle_header_updates(offset, data);
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
    require(msg_asset_id() == BASE_ASSET_ID, PythError::FeesCanOnlyBePayedInTheBaseAsset);

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

/////////////////////////////////
/// GENERAL PRIVATE FUNCTIONS ///
#[storage(read)]
fn total_fee(total_number_of_updates: u64) -> u64 {
    total_number_of_updates * storage.single_update_fee_in_wei.read()
}

//////////////////////////////////////////
/// PYTH ACCUMULATOR PRIVATE FUNCTIONS ///
#[storage(read)]
fn extract_wormhole_merkle_header_digest_and_num_updates_and_encoded_from_accumulator_update(
    accumulator_update: Bytes,
    encoded_offset: u64,
) -> (u64, Bytes, u64, Bytes) {
    //PLACEHOLDER 
    (1u64, Bytes::new(), 1u64, Bytes::new())
}

#[storage(read, write)]
fn update_price_feeds_from_accumulator_update(accumulator_update: Bytes) -> u64 {
    //PLACEHOLDER 
    1u64
    //internally check is each update is necessary
}

//////////////////////////////////////////
/// PYTH BATCH PRICE PRIVATE FUNCTIONS ///
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

//////////////////////////////////////
/// PYTHGETTERS PRIVATE FUNCTIONS ///
#[storage(read)]
fn latest_price_feed_publish_time(price_feed_id: PriceFeedId) -> u64 {
    match storage.latest_price_feed.get(price_feed_id).try_read() {
        Some(price_feed) => price_feed.price.publish_time,
        None => 0,
    }
}
