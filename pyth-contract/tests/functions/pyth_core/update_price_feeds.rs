use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_info::{price_feed_exists, price_feed_unsafe},
        pyth_init::constructor,
    },
    setup::{
        default_data_sources, default_price_feed_ids, default_update_data_bytes,
        guardian_set_upgrade_3_vaa_bytes, setup_environment, DEFAULT_SINGLE_UPDATE_FEE,
        DEFAULT_VALID_TIME_PERIOD,
    },
};
use fuels::types::Bytes;

mod success {

    use super::*;

    #[tokio::test]
    async fn updates_feeds() {
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
            default_update_data_bytes(),
        )
        .await;

        // TODO: Verify logs when implemented

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

        //Quick example
        let pf1 = price_feed_unsafe(
            &deployer.oracle_contract_instance,
            default_price_feed_ids()[0],
        )
        .await
        .value;
        let pf2 = price_feed_unsafe(
            &deployer.oracle_contract_instance,
            default_price_feed_ids()[1],
        )
        .await
        .value;

        println!("pf1:\n{:?}\n", pf1);
        println!("pf2:\n{:?}\n", pf2);
    }
}

/*
pf1:
price: Price { confidence: 70061350, exponent: 8, price: 164086958840, publish_time: 1695132706 }
real price = price * 1e(-exponent) = 1640.86958840

pf2:
price: Price { confidence: 21603, exponent: 8, price: 100001100, publish_time: 1695132706 }
real price = price * 1e(-exponent) = 1.00001100
*/
