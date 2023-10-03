use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_init::constructor,
    },
    setup::{
        default_data_sources, default_price_feed_ids, default_update_data_bytes,
        guardian_set_upgrade_3_vaa_bytes, setup_environment, DEFAULT_SINGLE_UPDATE_FEE,
        ETH_USD_PRICE_FEED, EXTENDED_TIME_PERIOD, USDC_USD_PRICE_FEED,
    },
};
use fuels::types::Bytes;

mod success {

    use crate::utils::{
        interface::pyth_core::price_no_older_than, setup::DEFAULT_VALID_TIME_PERIOD,
    };

    use super::*;

    #[tokio::test]
    async fn gets_price_no_older_than() {
        let (_oracle_contract_id, deployer) = setup_environment().await;

        constructor(
            &deployer.oracle_contract_instance,
            default_data_sources(),
            DEFAULT_SINGLE_UPDATE_FEE,
            DEFAULT_VALID_TIME_PERIOD,
            Bytes(guardian_set_upgrade_3_vaa_bytes()),
        )
        .await;

        let fee = update_fee(
            &deployer.oracle_contract_instance,
            default_update_data_bytes(),
        )
        .await
        .value;

        update_price_feeds(
            &deployer.oracle_contract_instance,
            fee,
            default_update_data_bytes(),
        )
        .await;

        let eth_usd_price = price_no_older_than(
            &deployer.oracle_contract_instance,
            EXTENDED_TIME_PERIOD,
            default_price_feed_ids()[0],
        )
        .await
        .value;
        let usdc_usd_price = price_no_older_than(
            &deployer.oracle_contract_instance,
            EXTENDED_TIME_PERIOD,
            default_price_feed_ids()[1],
        )
        .await
        .value;

        assert_eq!(
            (eth_usd_price.price as f64) * 10f64.powf(-(eth_usd_price.exponent as f64)),
            (ETH_USD_PRICE_FEED.price.price as f64)
                * 10f64.powf(-(ETH_USD_PRICE_FEED.price.exponent as f64)),
        );
        assert_eq!(
            (usdc_usd_price.price as f64) * 10f64.powf(-(usdc_usd_price.exponent as f64)),
            (USDC_USD_PRICE_FEED.price.price as f64)
                * 10f64.powf(-(USDC_USD_PRICE_FEED.price.exponent as f64)),
        );
    }
}
