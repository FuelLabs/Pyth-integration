use crate::utils::{
    interface::{
        pyth_core::{parse_price_feed_updates, update_fee},
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

    #[ignore = "Currently produces MemoryOverflow; requires investigation"]
    #[tokio::test]
    async fn parses_price_feed_updates() {
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

        let max_publish_time = ETH_USD_PRICE_FEED.price.publish_time;
        let price_feeds = parse_price_feed_updates(
            &deployer.oracle_contract_instance,
            fee,
            max_publish_time,
            max_publish_time - DEFAULT_VALID_TIME_PERIOD,
            default_price_feed_ids(),
            default_update_data_bytes(),
        )
        .await
        .value;

        assert_eq!(price_feeds[0], ETH_USD_PRICE_FEED);
        assert_eq!(price_feeds[1], USDC_USD_PRICE_FEED);
    }
}
