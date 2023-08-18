contract;

mod data_structures;
mod errors;
mod events;
mod interface;
mod utils;

use ::data_structures::{data_source::DataSource, price::{Price, PriceFeed, PriceFeedId}};
use ::errors::{PythError};
use ::interface::{IPyth, PythGetters, PythSetters};
use ::utils::difference;

use std::{
    block::timestamp,
    bytes::Bytes,
    constants::ZERO_B256,
    storage::{
        storage_map::StorageMap,
        storage_vec::StorageVec,
    },
    u256::U256,
};

storage {
    ///PythState///
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
    fn ema_price_no_older_than(time: u64, price_feed_id: PriceFeedId) -> Price {
        ema_price_no_older_than(time, price_feed_id)
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
fn ema_price_no_older_than(time: u64, price_feed_id: PriceFeedId) -> Price {
    let price = ema_price_unsafe(price_feed_id);

    require(difference(timestamp(), price.publish_time) <= time, PythError::OutdatedPrice);

    price
}

#[storage(read)]
fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price {
    let price_feed = storage.latest_price_info.get(price_feed_id).try_read();
    require(price_feed.is_some(), PythError::PriceFeedNotFound);

    price_feed.unwrap().ema_price
}

#[storage(read)]
fn valid_time_period() -> u64 {
    storage.valid_time_period_seconds.read()
}
