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
    // Confidence interval around the price
    confidence: u64,
    // Price exponent
    // exponent: u32,
    /*
    take 4 bytes from message i32 as array of u8s
    convert bytes array into u32
    bitshift to get absolute, unless 0
    for use, expo should be considered negative
    */
    // Price
    price: u64,
    // The timestamp describing when the price was published
    publish_time: u64,
}

impl Price {
    pub fn new(
        confidence: u64,
        exponent: u32,
        price: u64,
        publish_time: u64,
    ) -> Self {
        Self {
            confidence,
            exponent,
            price,
            publish_time,
        }
    }
}

/// The `PriceFeedId` type is an alias for `b256` that represents the id for a specific Pyth price feed.
pub type PriceFeedId = b256;

// PriceFeed represents a current aggregate price from Pyth publisher feeds.
pub struct PriceFeed {
    // Latest available exponentially-weighted moving average price
    ema_price: Price,
    // The price ID.
    id: PriceFeedId,
    // Latest available price
    price: Price,
}

impl PriceFeed {
    pub fn new(ema_price: Price, id: PriceFeedId, price: Price) -> Self {
        Self {
            ema_price,
            id,
            price,
        }
    }
}
