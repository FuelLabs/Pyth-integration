use crate::utils::interface::{
    pyth_core::{ema_price, update_fee, update_price_feeds},
    pyth_init::constructor,
};
use crate::utils::setup::setup_environment;
use fuels::types::Bytes;
use pyth_contract::pyth_utils::{
    default_accumulator_update_data_bytes, default_batch_update_data_bytes, default_data_sources,
    default_price_feed_ids, guardian_set_upgrade_3_vaa_bytes, ACCUMULATOR_ETH_USD_PRICE_FEED,
    ACCUMULATOR_USDC_USD_PRICE_FEED, BATCH_ETH_USD_PRICE_FEED, BATCH_USDC_USD_PRICE_FEED,
    DEFAULT_SINGLE_UPDATE_FEE, EXTENDED_TIME_PERIOD,
};

mod success {

    use super::*;

    #[tokio::test]
    async fn gets_ema_price_for_batch_update() {
        let (_oracle_contract_id, deployer) = setup_environment().await;

        constructor(
            &deployer.instance,
            default_data_sources(),
            DEFAULT_SINGLE_UPDATE_FEE,
            EXTENDED_TIME_PERIOD, //As the contract checks against the current timestamp, this allows unit testing with old but real price updates
            Bytes(guardian_set_upgrade_3_vaa_bytes()),
        )
        .await;

        let fee = update_fee(&deployer.instance, default_batch_update_data_bytes())
            .await
            .value;

        update_price_feeds(&deployer.instance, fee, default_batch_update_data_bytes()).await;

        let eth_usd_ema_price = ema_price(&deployer.instance, default_price_feed_ids()[0])
            .await
            .value;
        let usdc_usd_ema_price = ema_price(&deployer.instance, default_price_feed_ids()[1])
            .await
            .value;

        assert_eq!(
            (eth_usd_ema_price.price as f64) * 10f64.powf(-(eth_usd_ema_price.exponent as f64)),
            (BATCH_ETH_USD_PRICE_FEED.ema_price.price as f64)
                * 10f64.powf(-(BATCH_ETH_USD_PRICE_FEED.ema_price.exponent as f64)),
        );
        assert_eq!(
            (usdc_usd_ema_price.price as f64) * 10f64.powf(-(usdc_usd_ema_price.exponent as f64)),
            (BATCH_USDC_USD_PRICE_FEED.ema_price.price as f64)
                * 10f64.powf(-(BATCH_USDC_USD_PRICE_FEED.ema_price.exponent as f64)),
        );
    }

    #[tokio::test]
    async fn gets_ema_price_for_accumulator_update() {
        let (_oracle_contract_id, deployer) = setup_environment().await;

        constructor(
            &deployer.instance,
            default_data_sources(),
            DEFAULT_SINGLE_UPDATE_FEE,
            EXTENDED_TIME_PERIOD, //As the contract checks against the current timestamp, this allows unit testing with old but real price updates
            Bytes(guardian_set_upgrade_3_vaa_bytes()),
        )
        .await;

        let fee = update_fee(&deployer.instance, default_accumulator_update_data_bytes())
            .await
            .value;

        update_price_feeds(
            &deployer.instance,
            fee,
            default_accumulator_update_data_bytes(),
        )
        .await;

        let eth_usd_ema_price = ema_price(&deployer.instance, default_price_feed_ids()[0])
            .await
            .value;
        let usdc_usd_ema_price = ema_price(&deployer.instance, default_price_feed_ids()[1])
            .await
            .value;

        assert_eq!(
            (eth_usd_ema_price.price as f64) * 10f64.powf(-(eth_usd_ema_price.exponent as f64)),
            (ACCUMULATOR_ETH_USD_PRICE_FEED.ema_price.price as f64)
                * 10f64.powf(-(ACCUMULATOR_ETH_USD_PRICE_FEED.ema_price.exponent as f64)),
        );
        assert_eq!(
            (usdc_usd_ema_price.price as f64) * 10f64.powf(-(usdc_usd_ema_price.exponent as f64)),
            (ACCUMULATOR_USDC_USD_PRICE_FEED.ema_price.price as f64)
                * 10f64.powf(-(ACCUMULATOR_USDC_USD_PRICE_FEED.ema_price.exponent as f64)),
        );
    }
}
