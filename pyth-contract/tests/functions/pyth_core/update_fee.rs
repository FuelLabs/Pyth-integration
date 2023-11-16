use crate::utils::{
    interface::{pyth_core::update_fee, pyth_init::constructor},
    setup::{
        default_data_sources, default_update_data_bytes, guardian_set_upgrade_3_vaa_bytes,
        setup_environment, DEFAULT_SINGLE_UPDATE_FEE, DEFAULT_VALID_TIME_PERIOD,
    },
};
use fuels::types::Bytes;

mod success {

    use super::*;

    #[tokio::test]
    async fn gets_update_fee() {
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

        assert_eq!(fee, default_update_data_bytes().len() as u64);
    }
}
