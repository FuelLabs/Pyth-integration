library;

// A price with a degree of uncertainty, represented as a price +- a confidence interval.
//
// The confidence interval roughly corresponds to the standard error of a normal distribution.
// Both the price and confidence are stored in a fixed-point numeric representation,
// `x * (10^expo)`, where `expo` is the exponent.
//
// Please refer to the documentation at https://docs.pyth.network/documentation/pythnet-price-feeds/best-practices for how
// to how this price safely.
pub struct Price {
    // Price
    price: u64,
    // Confidence interval around the price
    confidence: u64,
    // Price exponent
    exponent: u32,
    // Unix timestamp describing when the price was published
    publish_time: u64,
}

/// The `PriceFeedId` type is an alias for `b256` that represents the id for a specific Pyth price feed.
pub type PriceFeedId = b256;

// PriceFeed represents a current aggregate price from Pyth publisher feeds.
pub struct PriceFeed {
    // The price ID.
    id: PriceFeedId,
    // Latest available price
    price: Price,
    // Latest available exponentially-weighted moving average price
    ema_price: Price,
}
