contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod pyth_accumulator;
mod utils;

use ::data_structures::{
    data_source::DataSource,
    price::{
        Price,
        PriceFeed,
        PriceFeedId,
    },
    pyth_accumulator::UpdateType,
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

    #[storage(read)]
    fn valid_time_period() -> u64 {
        valid_time_period()
    }
}
// impl PythSetters for Contract {
// }
// impl PythGetters for Contract {
// }










/// IPyth PRIVATE FUNCTIONS \\\
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