use fuels::{
    accounts::wallet::WalletUnlocked,
    prelude::{Bytes, CallParameters},
    programs::call_response::FuelCallResponse,
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

pub(crate) async fn update_price_feeds(
    contract: &PythOracleContract<WalletUnlocked>,
    fee: u64,
    update_data: Vec<Bytes>,
) -> FuelCallResponse<()> {
    contract
        .methods()
        .update_price_feeds(update_data)
        .call_params(CallParameters::default().with_amount(fee))
        .unwrap()
        .call()
        .await
        .unwrap()
}

pub(crate) async fn valid_time_period(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<u64> {
    contract.methods().valid_time_period().call().await.unwrap()
}
