use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_info::price_feed_exists,
        pyth_init::constructor,
    },
    setup::{
        default_accumulator_update_data_bytes, default_batch_update_data_bytes,
        default_data_sources, default_price_feed_ids, guardian_set_upgrade_3_vaa_bytes,
        setup_environment, DEFAULT_SINGLE_UPDATE_FEE, DEFAULT_VALID_TIME_PERIOD,
    },
};

use fuels::types::Bytes;

mod success {

    use super::*;

    #[tokio::test]
    async fn updates_price_feeds_for_batch_update() {
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

        // Initial values
        assert_eq!(
            (
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[0]
                )
                .await
                .value,
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[1]
                )
                .await
                .value
            ),
            (false, false)
        );

        update_price_feeds(
            &deployer.oracle_contract_instance,
            fee,
            default_batch_update_data_bytes(),
        )
        .await;

        // Final values
        assert_eq!(
            (
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[0]
                )
                .await
                .value,
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[1]
                )
                .await
                .value
            ),
            (true, true)
        );
    }

    #[tokio::test]
    async fn updates_price_feeds_for_accumulator_update() {
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

        // Initial values
        assert_eq!(
            (
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[0]
                )
                .await
                .value,
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[1]
                )
                .await
                .value
            ),
            (false, false)
        );

        update_price_feeds(
            &deployer.oracle_contract_instance,
            fee,
            default_accumulator_update_data_bytes(),
        )
        .await;

        // Final values
        assert_eq!(
            (
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[0]
                )
                .await
                .value,
                price_feed_exists(
                    &deployer.oracle_contract_instance,
                    default_price_feed_ids()[1]
                )
                .await
                .value
            ),
            (true, true)
        );
    }
}
