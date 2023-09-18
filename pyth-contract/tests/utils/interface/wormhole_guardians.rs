use crate::utils::setup::{PythOracleContract, WormholeProvider};
use fuels::{
    accounts::wallet::WalletUnlocked, programs::call_response::FuelCallResponse, types::Bits256,
};

pub(crate) async fn current_guardian_set_index(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<u32> {
    contract
        .methods()
        .current_guardian_set_index()
        .call()
        .await
        .unwrap()
}

pub(crate) async fn current_wormhole_provider(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<WormholeProvider> {
    contract
        .methods()
        .current_wormhole_provider()
        .call()
        .await
        .unwrap()
}

pub(crate) async fn governance_action_is_consumed(
    contract: &PythOracleContract<WalletUnlocked>,
    governance_action_hash: Bits256,
) -> FuelCallResponse<bool> {
    contract
        .methods()
        .governance_action_is_consumed(governance_action_hash)
        .call()
        .await
        .unwrap()
}
