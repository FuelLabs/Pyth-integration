library;

/// Error log for a Pyth oracle revert.
pub enum PythError {
    InsufficientFee: (),
    InvalidUpdateData: (),
    /// Emitted when a Price's `publish_time` is stale.
    OutdatedPrice: (),
    /// Emitted when a PriceFeed could not be retrived.
    PriceFeedNotFound: (),
    PriceFeedNotFoundWithinRange: (),
}
