library;

/// Error log for a Pyth oracle revert.
pub enum PythError {
    FeesCanOnlyBePaidInTheBaseAsset: (),
    GuardianSetNotFound: (),
    InsufficientFee: (),
    InvalidArgument: (),
    InvalidUpdateData: (),
    InvalidUpgradeModule: (),
    NewGuardianSetIsEmpty: (),
    NewGuardianSetIndexIsInvalid: (),
    /// Emitted when a Price's `publish_time` is stale.
    OutdatedPrice: (),
    /// Emitted when a PriceFeed could not be retrieved.
    PriceFeedNotFound: (),
    PriceFeedNotFoundWithinRange: (),
    WormholeGovernanceActionNotFound: (),
}
