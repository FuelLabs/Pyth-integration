library;

use ::data_structures::{
    data_source::DataSource,
    price::PriceFeedId,
    wormhole_light::WormholeProvider,
};

pub struct ConstructedEvent {
    single_update_fee: u64,
    valid_data_sources: Vec<DataSource>,
    valid_time_period_seconds: u64,
    wormhole_provider: WormholeProvider,
}

pub struct NewGuardianSetEvent {
    governance_action_hash: b256,
    // new_guardian_set: GuardianSet, // TODO: Uncomment when SDK supports logs with nested Vecs https://github.com/FuelLabs/fuels-rs/issues/1046
    new_guardian_set_index: u32,
}

pub struct UpdatedPriceFeedsEvent {
    updated_price_feeds: Vec<PriceFeedId>,
}
