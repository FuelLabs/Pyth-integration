library;

pub enum PythError {
    FeesCanOnlyBePaidInTheBaseAsset: (),
    GuardianSetNotFound: (),
    IncorrectMessageType: (),
    InsufficientFee: (),
    InvalidArgument: (),
    InvalidAttestationSize: (),
    InvalidDataSourcesLength: (),
    InvalidExponent: (),
    InvalidHeaderSize: (),
    InvalidMagic: (),
    InvalidMajorVersion: (),
    InvalidMinorVersion: (),
    InvalidPayloadId: (),
    InvalidPayloadLength: (),
    InvalidPriceFeedDataLength: (),
    InvalidProof: (),
    InvalidUpdateData: (),
    InvalidUpdateDataLength: (),
    InvalidUpdateDataSource: (),
    InvalidUpgradeModule: (),
    LengthOfPriceFeedIdsAndPublishTimesMustMatch: (),
    NewGuardianSetIsEmpty: (),
    NumberOfUpdatesIrretrievable: (),
    /// Emitted when a Price's `publish_time` is stale.
    OutdatedPrice: (),
    /// Emitted when a PriceFeed could not be retrieved.
    PriceFeedNotFound: (),
    PriceFeedNotFoundWithinRange: (),
    WormholeGovernanceActionNotFound: (),
}
