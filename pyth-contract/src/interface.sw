library;

use ::data_structures::{price::{Price, PriceFeed, PriceFeedId}};
use std::{bytes::Bytes, u256::U256};

abi Pyth {
    /// @notice Returns the period (in seconds) that a price feed is considered valid since its publish time
    fn valid_time_period() -> U256;

    /// @notice Returns the required fee to update an array of price updates.
    /// @param update_data Array of price update data.
    /// @return The required fee in Wei.
    fn update_fee(update_data: Bytes) -> u64;

    /// @notice Update price feeds with given update messages.
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    /// Prices will be updated if they are more recent than the current stored prices.
    /// The call will succeed even if the update is not the most recent.
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid.
    /// @param update_data Array of price update data.
    fn update_price_feeds(update_data: Bytes);

    /// @notice Wrapper around updatePriceFeeds that rejects fast if a price update is not necessary. A price update is
    /// necessary if the current on-chain publishTime is older than the given publishTime. It relies solely on the
    /// given `publishTimes` for the price feeds and does not read the actual price update publish time within `updateData`.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    /// `priceIds` and `publishTimes` are two arrays with the same size that correspond to senders known publishTime
    /// of each priceId when calling this method. If all of price feeds within `priceIds` have updated and have
    /// a newer or equal publish time than the given publish time, it will reject the transaction to save gas.
    /// Otherwise, it calls updatePriceFeeds method to update the prices.
    ///
    /// @dev Reverts if update is not needed or the transferred fee is not sufficient or the updateData is invalid.
    /// @param update_data Array of price update data.
    /// @param price_feed_ids Array of price ids.
    /// @param publish_times Array of publishTimes. `publishTimes[i]` corresponds to known `publishTime` of `priceIds[i]`
    fn update_price_feeds_if_necessary(price_feed_ids: Vec<PriceFeedId>, publish_times: Vec<u256>, update_data: Bytes);

    /// @notice Returns the price and confidence interval.
    /// @dev Reverts if the price has not been updated within the last `getValidTimePeriod()` seconds.
    /// @param price_feed_id The Pyth Price Feed ID of which to fetch the price and confidence interval.
    /// @return please read the documentation of PythStructs.Price to understand how to use this safely.
    fn price(price_feed_id: PriceFeedId) -> Price;

    /// @notice Returns the exponentially-weighted moving average price and confidence interval.
    /// @dev Reverts if the EMA price is not available.
    /// @param price_feed_id The Pyth Price Feed ID of which to fetch the EMA price and confidence interval.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    fn ema_price(price_feed_id: PriceFeedId) -> Price;

    /// @notice Returns the price of a price feed without any sanity checks.
    /// @dev This function returns the most recent price update in this contract without any recency checks.
    /// This function is unsafe as the returned price update may be arbitrarily far in the past.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getPrice` or `getPriceNoOlderThan`.
    /// @return price - please read the documentation of PythStructs.Price to understand how to use this safely.
    fn price_unsafe(price_feed_id: PriceFeedId) -> Price;

    /// @notice Returns the price that is no older than `age` seconds of the current time.
    /// @dev This function is a sanity-checked version of `getPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return  please read the documentation of PythStructs.Price to understand how to use this safely.
    fn price_no_older_than(age: U256, price_feed_id: PriceFeedId) -> Price;

    /// @notice Returns the exponentially-weighted moving average price of a price feed without any sanity checks.
    /// @dev This function returns the same price as `getEmaPrice` in the case where the price is available.
    /// However, if the price is not recent this function returns the latest available price.
    ///
    /// The returned price can be from arbitrarily far in the past; this function makes no guarantees that
    /// the returned price is recent or useful for any particular application.
    ///
    /// Users of this function should check the `publishTime` in the price to ensure that the returned price is
    /// sufficiently recent for their application. If you are considering using this function, it may be
    /// safer / easier to use either `getEmaPrice` or `getEmaPriceNoOlderThan`.
    /// @return  please read the documentation of PythStructs.Price to understand how to use this safely.
    fn ema_price_unsafe(price_feed_id: PriceFeedId) -> Price;

    /// @notice Returns the exponentially-weighted moving average price that is no older than `age` seconds
    /// of the current time.
    /// @dev This function is a sanity-checked version of `getEmaPriceUnsafe` which is useful in
    /// applications that require a sufficiently-recent price. Reverts if the price wasn't updated sufficiently
    /// recently.
    /// @return  please read the documentation of PythStructs.Price to understand how to use this safely.
    fn ema_price_no_older_than(age: U256, price_feed_id: PriceFeedId) -> Price;

    /// @notice Parse `updateData` and return price feeds of the given `priceIds` if they are all published
    /// within `minPublishTime` and `maxPublishTime`.
    ///
    /// You can use this method if you want to use a Pyth price at a fixed time and not the most recent price;
    /// otherwise, please consider using `updatePriceFeeds`. This method does not store the price updates on-chain.
    ///
    /// This method requires the caller to pay a fee in wei; the required fee can be computed by calling
    /// `getUpdateFee` with the length of the `updateData` array.
    ///
    ///
    /// @dev Reverts if the transferred fee is not sufficient or the updateData is invalid or there is
    /// no update for any of the given `priceIds` within the given time range.
    /// @param update_data Array of price update data.
    /// @param price_feed_ids Array of price ids.
    /// @param min_publish_time minimum acceptable publishTime for the given `priceIds`.
    /// @param max_publish_time maximum acceptable publishTime for the given `priceIds`.
    /// @return Array of the price feeds corresponding to the given `priceIds` (with the same order).
    fn parse_price_feed_updates(max_publish_time: U256, min_publish_time: U256, price_feed_ids: Vec<PriceFeedId>, update_data: Bytes) -> Vec<PriceFeed>;
}
