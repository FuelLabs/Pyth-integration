library;

pub mod errors;
pub mod data_structures;

use ::data_structures::{guardian_set::GuardianSet, wormhole_provider::WormholeProvider};
use std::bytes::Bytes;

abi WormholeGuardians {
    #[storage(read)]
    fn current_guardian_set_index() -> u32;

    #[storage(read)]
    fn current_wormhole_provider() -> WormholeProvider;

    #[storage(read)]
    fn governance_action_is_consumed(hash: b256) -> bool;

    #[storage(read)]
    fn guardian_set(index: u32) -> GuardianSet;

    #[storage(read, write)]
    fn submit_new_guardian_set(vm: Bytes);
}
