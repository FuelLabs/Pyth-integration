use crate::utils::{
    interface::{
        pyth_core::{update_fee, update_price_feeds},
        pyth_init::constructor,
    },
    setup::{
        default_data_sources, default_update_data_bytes, guardian_set_upgrade_3_vaa_bytes,
        setup_environment, DEFAULT_SINGLE_UPDATE_FEE, DEFAULT_VALID_TIME_PERIOD,
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

        // let response = update_fee(
        //     &deployer.oracle_contract_instance,
        //     default_update_data_bytes(),
        // )
        // .await;

        // assert_eq!(response.value, default_update_data_bytes().len() as u64);

        update_price_feeds(
            &deployer.oracle_contract_instance,
            default_update_data_bytes(),
        )
        .await;
    }
}
