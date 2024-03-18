use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_info::price_feed_unsafe,
        pyth_init::constructor,
    },
    setup::{
        default_accumulator_update_data_bytes, default_batch_update_data_bytes,
        default_data_sources, default_price_feed_ids, guardian_set_upgrade_3_vaa_bytes,
        setup_environment, ACCUMULATOR_ETH_USD_PRICE_FEED, ACCUMULATOR_USDC_USD_PRICE_FEED,
        BATCH_ETH_USD_PRICE_FEED, BATCH_USDC_USD_PRICE_FEED, DEFAULT_SINGLE_UPDATE_FEE,
        DEFAULT_VALID_TIME_PERIOD,
    },
};
use fuels::types::Bytes;

mod success {

    use super::*;

    #[tokio::test]
    async fn gets_price_feed_from_batch_update() {
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
            default_batch_update_data_bytes(),
        )
        .await
        .value;

        update_price_feeds(
            &deployer.oracle_contract_instance,
            fee,
            default_batch_update_data_bytes(),
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

        assert_eq!(eth_usd_price_feed, BATCH_ETH_USD_PRICE_FEED);
        assert_eq!(usdc_usd_price_feed, BATCH_USDC_USD_PRICE_FEED);
    }

    #[tokio::test]
    async fn gets_price_feed_from_accumulator_update() {
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
            default_accumulator_update_data_bytes(),
        )
        .await
        .value;

        update_price_feeds(
            &deployer.oracle_contract_instance,
            fee,
            default_accumulator_update_data_bytes(),
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

        assert_eq!(eth_usd_price_feed, ACCUMULATOR_ETH_USD_PRICE_FEED);
        assert_eq!(usdc_usd_price_feed, ACCUMULATOR_USDC_USD_PRICE_FEED);
    }
}
