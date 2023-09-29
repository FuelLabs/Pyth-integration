use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_info::price_feed_unsafe,
        pyth_init::constructor,
    },
    setup::{
        default_data_sources, default_price_feed_ids, default_update_data_bytes,
        guardian_set_upgrade_3_vaa_bytes, setup_environment, DEFAULT_SINGLE_UPDATE_FEE,
        DEFAULT_VALID_TIME_PERIOD, ETH_USD_PRICE_FEED, USDC_USD_PRICE_FEED,
    },
};
use fuels::types::Bytes;

mod success {

    use super::*;

    #[tokio::test]
    async fn gets_price_feed() {
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

        let eth_usd_price_feed = price_feed_unsafe(
            &deployer.oracle_contract_instance,
            default_price_feed_ids()[0],
        )
        .await
        .value;
        let usdc_usd_price_feed = price_feed_unsafe(
            &deployer.oracle_contract_instance,
            default_price_feed_ids()[1],
        )
        .await
        .value;

        assert_eq!(eth_usd_price_feed, ETH_USD_PRICE_FEED);
        assert_eq!(usdc_usd_price_feed, USDC_USD_PRICE_FEED);
    }
}
