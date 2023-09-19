use fuels::{
    accounts::wallet::WalletUnlocked, prelude::Bytes, programs::call_response::FuelCallResponse,
};

use crate::utils::setup::PythOracleContract;

pub(crate) async fn update_fee(
    contract: &PythOracleContract<WalletUnlocked>,
    update_data: Vec<Bytes>,
) -> FuelCallResponse<u64> {
    contract
        .methods()
        .update_fee(update_data)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn valid_time_period(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<u64> {
    contract.methods().valid_time_period().call().await.unwrap()
}
