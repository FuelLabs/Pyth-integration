library;

use pyth_interface::data_structures::price::PriceFeedId;

pub struct ConstructedEvent {
    pub guardian_set_index: u32,
}

pub struct NewGuardianSetEvent {
    pub governance_action_hash: b256,
    // pub new_guardian_set: GuardianSet, // TODO: Uncomment when SDK supports logs with nested Vecs https://github.com/FuelLabs/fuels-rs/issues/1046
    pub new_guardian_set_index: u32,
}

pub struct UpdatedPriceFeedsEvent {
    pub updated_price_feeds: Vec<PriceFeedId>,
}
