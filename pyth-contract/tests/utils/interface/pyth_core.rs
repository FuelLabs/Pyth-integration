use fuels::{
    accounts::wallet::WalletUnlocked,
    prelude::{Bytes, CallParameters, TxParameters, DEFAULT_GAS_LIMIT},
    programs::call_response::FuelCallResponse,
    types::Bits256,
};

use crate::utils::setup::{Price, PriceFeed, PythOracleContract};

pub(crate) async fn ema_price(
    contract: &PythOracleContract<WalletUnlocked>,
    price_feed_id: Bits256,
) -> FuelCallResponse<Price> {
    contract
        .methods()
        .ema_price(price_feed_id)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn ema_price_no_older_than(
    contract: &PythOracleContract<WalletUnlocked>,
    time_period: u64,
    price_feed_id: Bits256,
) -> FuelCallResponse<Price> {
    contract
        .methods()
        .ema_price_no_older_than(time_period, price_feed_id)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn ema_price_unsafe(
    contract: &PythOracleContract<WalletUnlocked>,
    price_feed_id: Bits256,
) -> FuelCallResponse<Price> {
    contract
        .methods()
        .ema_price_unsafe(price_feed_id)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn parse_price_feed_updates(
    contract: &PythOracleContract<WalletUnlocked>,
    fee: u64,
    max_publish_time: u64,
    min_publish_time: u64,
    price_feed_ids: Vec<Bits256>,
    update_data: Vec<Bytes>,
) -> FuelCallResponse<Vec<PriceFeed>> {
    contract
        .methods()
        .parse_price_feed_updates(
            max_publish_time,
            min_publish_time,
            price_feed_ids,
            update_data,
        )
        .tx_params(TxParameters::default().with_gas_limit(DEFAULT_GAS_LIMIT * 2))
        .call_params(CallParameters::default().with_amount(fee))
        .unwrap()
        .call()
        .await
        .unwrap()
}

pub(crate) async fn price(
    contract: &PythOracleContract<WalletUnlocked>,
    price_feed_id: Bits256,
) -> FuelCallResponse<Price> {
    contract
        .methods()
        .price(price_feed_id)
        .call()
        .await
        .unwrap()
}

pub(crate) async fn price_no_older_than(
    contract: &PythOracleContract<WalletUnlocked>,
    time_period: u64,
    price_feed_id: Bits256,
) -> FuelCallResponse<Price> {
    contract
        .methods()
        .price_no_older_than(time_period, price_feed_id)
        .call()
        .await
        .unwrap()
}

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
