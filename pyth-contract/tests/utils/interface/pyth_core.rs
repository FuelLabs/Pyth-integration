use fuels::{accounts::wallet::WalletUnlocked, programs::call_response::FuelCallResponse};

use crate::utils::setup::PythOracleContract;

pub(crate) async fn valid_time_period(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<u64> {
    contract.methods().valid_time_period().call().await.unwrap()
}
