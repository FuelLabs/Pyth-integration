library;

use ::data_structures::{data_source::DataSource, price::{Price, PriceFeed, PriceFeedId}};
use std::{bytes::Bytes, storage::storage_vec::*};

//abis: IPyth, setters, getters, governance, upgradeability

abi IPyth {
    /// This function returns the exponentially-weighted moving average price and confidence interval.
    ///
    /// # Arguments
    ///
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    ///
    /// # Reverts
    ///
    /// * When the EMA price is not available.
    #[storage(read)]
    fn ema_price(price_feed_id: PriceFeedId) -> Price;

    /// This function Returns the exponentially-weighted moving average price that is no older than `time` seconds
    /// from the current time.
    ///
    /// # Additional Information
    ///
    /// This function is a sanity-checked version of `ema_price_unsafe` which is useful in
    /// applications that require a sufficiently-recent price.
    ///
    /// # Arguments
    ///
    /// * `time_period`: [u64] - The period (in seconds) that a price feed is considered valid since its publish time.
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    ///
    /// # Reverts
    ///
    /// * When the EMA price is not available.
    /// * When the the EMA price wasn't updated recently enough.
    #[storage(read)]
    fn ema_price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price;

    /// This function returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    ///
    /// # Additional Information
    ///
    /// This function returns the same price as `ema_price` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publish_time` in the `Price` to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `ema_price` or `ema_price_no_older_than`.
    ///
    /// # Arguments
    ///
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    #[storage(read)]
    fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price;

    /// This function parses `update_data` and returns price feeds of the given `price_feed_ids` if they are all published
    /// within `min_publish_time` and `max_publish_time`.
    ///
    /// # Additional Information
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `update_price_feeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `update_fee`.
    ///
    /// # Arguments
    ///
    /// * `max_publish_time`: [u64] - The maximum acceptable `publish_time` for the given `price_feed_ids`.
    /// * `min_publish_time`: [u64] - The minimum acceptable `publish_time` for the given `price_feed_ids`.
    /// * `price_feed_ids`: [Vec<PriceFeedId>] - The ids of the price feeds to return PriceFeed data for.
    /// * `update_data`: [Bytes] - The price update data.
    ///
    /// # Returns
    ///
    /// * [u64] - The number of hashes performed.
    ///
    /// # Reverts
    ///
    /// * When the transferred fee is not sufficient
    /// * When the update_data is invalid
    /// * When there is no update for any of the given `priceIds` within the given time range.
    #[storage(read), payable]
    fn parse_price_feed_updates(max_publish_time: u64, min_publish_time: u64, price_feed_ids: Vec<PriceFeedId>, update_data: Vec<Bytes>) -> Vec<PriceFeed>;

    /// This function returns the price and confidence interval.
    ///
    /// # Additional Information
    ///
    /// This function also has some complex behaviours.
    ///
    /// # Arguments
    ///
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    ///
    /// # Reverts
    ///
    /// * When the price has not been updated within the last valid time period.
    #[storage(read)]
    fn price(price_feed_id: PriceFeedId) -> Price;

    /// This function returns the price that is no older than `time` seconds of the current time.
    ///
    /// # Additional Information
    ///
    /// This function is a sanity-checked version of `price_unsafe` which is useful in applications that require a
    /// sufficiently-recent price. Reverts if the price wasn't updated sufficiently recently.
    ///
    /// # Arguments
    ///
    /// * `time_period`: [u64] - The period (in seconds) that a price feed is considered valid since its publish time.
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    ///
    /// # Reverts
    ///
    /// * When the price is not available.
    /// * When the price wasn't updated recently enough.
    #[storage(read)]
    fn price_no_older_than(time_period: u64, price_feed_id: PriceFeedId) -> Price;

    /// This function returns the price of a price feed without any sanity checks.
    ///
    /// # Additional Information
    ///
    /// This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publish_time` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `price_no_older_than`.
    ///
    /// # Arguments
    ///
    /// * `price_feed_id`: [PriceFeedId] - The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    ///
    /// # Returns
    ///
    /// * [Price] - Please read the documentation of data_structures::price to understand how to use this safely.
    #[storage(read)]
    fn price_unsafe(price_feed_id: PriceFeedId) -> Price;

    /// This function returns the required fee in Wei to update an array of price updates.
    ///
    /// # Arguments
    ///
    /// * `update_data`: [Bytes] - The price update data.
    ///
    /// # Returns
    ///
    /// * [u64] - The required fee in Wei.
    #[storage(read)]
    fn update_fee(update_data: Vec<Bytes>) -> u64;

    /// This function updates price feeds with the given update messages.
    ///
    /// # Additional Information
    ///
    /// This function requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `update_fee`.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    ///
    /// # Arguments
    ///
    /// * `update_data`: [Bytes] - The price update data.
    ///
    /// # Reverts
    ///
    /// * When the transferred fee is not sufficient.
    /// * When the `update_data` is invalid.
    #[storage(read, write), payable]
    fn update_price_feeds(update_data: Vec<Bytes>);

    /// This function is a wrapper around `update_price_feeds` that reverts fast if a price update is not necessary.
    ///
    /// # Additional Information
    ///
    /// A price update is necessary if the current on-chain `publish_time` is older than the given `publish_time`. It relies solely on the
    /// given `publish_time` for the price feeds and does not read the actual price update publish time within `update_data`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `update_fee`.
    ///
    /// `price_feed_ids` and `publish_times` are two arrays with the same size that correspond to senders known `publish_time`
    /// of each PriceFeedId when calling this method. If all of price feeds within `price_feed_ids` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls `update_price_feeds` to update the prices.
    ///
    /// # Arguments
    ///
    /// * `price_feed_ids`: [Vec<PriceFeedId>] - Vector of price feed ids; `price_feed_ids[i]` corresponds to known price feed id  of `publish_times[i]`.
    /// * `publish_times`: [Vec<u64>] - Vector of publish times; `publish_times[i]` corresponds to known publish time of `price_feed_ids[i]`.
    /// * `update_data`: [Bytes] - The price update data.
    ///
    ///
    /// # Reverts
    ///
    /// * When update is not necessary.
    /// * When the transferred fee is not sufficient.
    /// * When the `update_data` is invalid.
    #[storage(read, write), payable]
    fn update_price_feeds_if_necessary(price_feed_ids: Vec<PriceFeedId>, publish_times: Vec<u64>, update_data: Vec<Bytes>);

    /// This function returns the period (in seconds) that a price feed is considered valid since its publish time.
    ///
    /// # Returns
    ///
    /// * [u64] - The period (in seconds) that a price feed is considered valid since its publish time.
    #[storage(read)]
    fn valid_time_period() -> u64;
}

abi PythSetters {
    #[storage(read, write)]
    fn initialise(wormhole_contract_id: ContractId, data_source_emitter_chain_ids: Vec<u16>, data_source_emitter_addresses: Vec<b256>, governance_emitter_chainId: u16, governance_emitter_address: b256, governance_initial_sequence: u64, valid_time_period_seconds: u64, single_update_fee_in_wei: u64);
}

abi PythGetters {
    #[storage(read)]
    fn chain_id() -> u16;

    #[storage(read)]
    fn current_valid_data_sources() -> StorageVec<DataSource>;

    //TODO uncomment when Hash is included in release
    // fn hashDataSource(data_source: DataSource) -> b256;

    #[storage(read)]
    fn latest_price_feed_publish_time(price_feed_id: PriceFeedId) -> u64;

    /// @notice Returns true if a price feed with the given id exists.
    /// @param price_feed_id The Pyth Price Feed ID of which to check its existence.
    #[storage(read)]
    fn price_feed_exists(price_feed_id: PriceFeedId) -> bool;

    /// @notice Returns the price feed with given id.
    /// @dev Reverts if the price does not exist.
    /// @param price_feed_id The Pyth Price Feed ID of which to fetch the PriceFeed.
    #[storage(read)]
    fn query_price_feed(price_feed_id: PriceFeedId) -> PriceFeed;

    //TODO uncomment when Hash is included in release
    // #[storage(read)]
    // fn valid_data_source(data_source_chain_id: u16, data_source_emitter_address: b256) -> bool;
}
