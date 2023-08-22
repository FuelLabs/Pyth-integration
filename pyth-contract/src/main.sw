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
    pyth_accumulator::UpdateType,
    wormhole::{
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
use ::utils::{difference, find_index_of_price_feed_id};

use std::{
    block::timestamp,
    bytes::Bytes,
    constants::ZERO_B256,
    context::msg_amount,
    storage::{
        storage_map::StorageMap,
        storage_vec::StorageVec,
    },
    u256::U256,
};

storage {
    /// PythState ///
    // Mapping of cached price information
    // priceId => PriceInfo
    latest_price_info: StorageMap<PriceFeedId, PriceFeed> = StorageMap {},
    single_update_fee_in_wei: u64 = 1,
    // (chainId, emitterAddress) => isValid; takes advantage of
    // constant-time mapping lookup for VM verification
    is_valid_data_source: StorageMap<b256, bool> = StorageMap {},
    // For tracking all active emitter/chain ID pairs
    valid_data_sources: StorageVec<DataSource> = StorageVec {},
    /// Maximum acceptable time period before price is considered to be stale.
    /// This includes attestation delay, block time, and potential clock drift
    /// between the source/target chains.
    valid_time_period_seconds: u64 = 1,
    wormhole: ContractId = ContractId {
        value: ZERO_B256,
    },
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

    #[storage(read, write), payable]
    fn parse_price_feed_updates(
        max_publish_time: u64,
        min_publish_time: u64,
        price_feed_ids: Vec<PriceFeedId>,
        update_data: Vec<Bytes>,
    ) -> Vec<PriceFeed> {
        let required_fee = update_fee(update_data);
        require(msg_amount() >= required_fee, PythError::InsufficientFee);

        let mut price_feeds: Vec<PriceFeed> = Vec::with_capacity(price_feed_ids.len);

        let mut index = 0;
        let update_data_length = update_data.len;
        while index < update_data_length {
            let data = update_data.get(index).unwrap();

            if data.len > 4 && data == accumulator_magic_bytes(ACCUMULATOR_MAGIC) {
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
            } else {
                let vm = parse_and_verify_batch_attestation_VM(data);
                let encoded_payload = vm.payload;

                // Batch price logic
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
                require(offset == encoded.len, PythError::InvalidUpdateData);
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
    fn update_fee(update_data: Vec<Bytes>) -> u64 {
        update_fee(update_data)
    }

    #[storage(read)]
    fn valid_time_period() -> u64 {
        valid_time_period()
    }
}
// impl PythSetters for Contract {
// }
// impl PythGetters for Contract {
// }



/// IPyth PRIVATE FUNCTIONS ///
#[storage(read)]
fn ema_price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price {
    let price = ema_price_unsafe(price_feed_id);

    require(difference(timestamp(), price.publish_time) <= time_period, PythError::OutdatedPrice);

    price
}

#[storage(read)]
fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price {
    let price_feed = storage.latest_price_info.get(price_feed_id).try_read();
    require(price_feed.is_some(), PythError::PriceFeedNotFound);

    price_feed.unwrap().ema_price
}

#[storage(read)]
fn update_fee(update_data: Vec<Bytes>) -> u64 {
    let mut total_number_of_updates = 0;
    let mut index = 0;
    let update_data_length = update_data.len;
    while index < update_data_length {
        let data = update_data.get(index).unwrap();

        if data.len > 4
            && data == accumulator_magic_bytes(ACCUMULATOR_MAGIC)
        {
            let (offset, _update_type) = extract_update_type_from_accumulator_header(data);

            total_number_of_updates += parse_wormhole_merkle_header_updates(offset, data);
        } else {
            total_number_of_updates += 1;
        }

        index += 1;
    }

    total_fee(total_number_of_updates)
}

#[storage(read)]
fn valid_time_period() -> u64 {
    storage.valid_time_period_seconds.read()
}

/// GENERAL PRIVATE FUNCTIONS ///
#[storage(read)]
fn total_fee(total_number_of_updates: u64) -> u64 {
    total_number_of_updates * storage.single_update_fee_in_wei.read()
}

/// PYTH ACCUMULATOR PRIVATE FUNCTIONS ///
#[storage(read)]
extract_wormhole_merkle_header_digest_and_num_updates_and_encoded_from_accumulator_update(accumulator_update: Bytes, encoded_offset: u64) -> (u64, Bytes, u64, Bytes) {
    //TMP
    (1u64, Bytes::new(), 1u64, Bytes::new())
}