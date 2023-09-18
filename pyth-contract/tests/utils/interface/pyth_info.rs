use fuels::{accounts::wallet::WalletUnlocked, programs::call_response::FuelCallResponse};

use crate::utils::setup::{DataSource, PythOracleContract, State};

pub(crate) async fn owner(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<State> {
    contract.methods().owner().call().await.unwrap()
}

pub(crate) async fn single_update_fee(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<u64> {
    contract.methods().single_update_fee().call().await.unwrap()
}

pub(crate) async fn valid_data_source(
    contract: &PythOracleContract<WalletUnlocked>,
    data_source: DataSource,
) -> FuelCallResponse<bool> {
    contract
        .methods()
        .valid_data_source(data_source)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn valid_data_sources(
    contract: &PythOracleContract<WalletUnlocked>,
) -> FuelCallResponse<Vec<DataSource>> {
    contract
        .methods()
        .valid_data_sources()
        .call()
        .await
        .unwrap()
}
