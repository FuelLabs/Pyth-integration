use crate::utils::{
    interface::{
        pyth_core::{parse_price_feed_updates, update_fee},
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
    async fn parses_price_feed_batch_updates() {
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

        let max_publish_time = BATCH_ETH_USD_PRICE_FEED.price.publish_time;
        let price_feeds = parse_price_feed_updates(
            &deployer.oracle_contract_instance,
            fee,
            max_publish_time,
            max_publish_time - DEFAULT_VALID_TIME_PERIOD,
            default_price_feed_ids(),
            default_batch_update_data_bytes(),
        )
        .await
        .value;

        assert_eq!(price_feeds[0], BATCH_ETH_USD_PRICE_FEED);
        assert_eq!(price_feeds[1], BATCH_USDC_USD_PRICE_FEED);
    }

    #[tokio::test]
    async fn parses_price_feed_accumulator_updates() {
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

        let max_publish_time = ACCUMULATOR_ETH_USD_PRICE_FEED.price.publish_time;
        let price_feeds = parse_price_feed_updates(
            &deployer.oracle_contract_instance,
            fee,
            max_publish_time,
            max_publish_time - DEFAULT_VALID_TIME_PERIOD,
            default_price_feed_ids(),
            default_accumulator_update_data_bytes(),
        )
        .await
        .value;

        assert_eq!(price_feeds[0], ACCUMULATOR_ETH_USD_PRICE_FEED);
        assert_eq!(price_feeds[1], ACCUMULATOR_USDC_USD_PRICE_FEED);
    }
}
