use crate::utils::{
    interface::{
        pyth_core::valid_time_period,
        pyth_info::{owner, single_update_fee, valid_data_source, valid_data_sources},
        pyth_init::constructor,
        wormhole_guardians::{
            current_guardian_set_index, current_wormhole_provider, governance_action_is_consumed,
        },
    },
    setup::{
        default_data_sources, guardian_set_upgrade_3_vaa_bytes, setup_environment,
        ConstructedEvent, State, WormholeProvider, DEFAULT_SINGLE_UPDATE_FEE,
        DEFAULT_VALID_TIME_PERIOD, UPGRADE_3_VAA_GOVERNANCE_ACTION_HASH,
    },
};
use fuels::{
    prelude::Address,
    types::{Bits256, Bytes},
};

mod success {

    use fuels::types::Identity;

    use super::*;

    #[tokio::test]
    async fn constructs() {
        let (_oracle_contract_id, deployer) = setup_environment().await;

        // Initial values
        assert!(
            !valid_data_source(
                &deployer.oracle_contract_instance,
                &default_data_sources()[0]
            )
            .await
            .value
        );
        assert_eq!(
            valid_data_sources(&deployer.oracle_contract_instance)
                .await
                .value
                .len(),
            0
        );
        assert_eq!(
            valid_time_period(&deployer.oracle_contract_instance)
                .await
                .value,
            0
        );
        assert_eq!(
            single_update_fee(&deployer.oracle_contract_instance)
                .await
                .value,
            0
        );
        assert!(
            !governance_action_is_consumed(
                &deployer.oracle_contract_instance,
                UPGRADE_3_VAA_GOVERNANCE_ACTION_HASH
            )
            .await
            .value
        );
        assert_eq!(
            current_guardian_set_index(&deployer.oracle_contract_instance,)
                .await
                .value,
            0
        );
        assert_eq!(
            current_wormhole_provider(&deployer.oracle_contract_instance,)
                .await
                .value,
            WormholeProvider {
                governance_chain_id: 0,
                governance_contract: Bits256::zeroed(),
            }
        );
        assert_eq!(
            owner(&deployer.oracle_contract_instance,).await.value,
            State::Initialized(Identity::Address(Address::from(
                &deployer.wallet.address().into()
            )))
        );

        let response = constructor(
            &deployer.oracle_contract_instance,
            default_data_sources(),
            DEFAULT_SINGLE_UPDATE_FEE,
            DEFAULT_VALID_TIME_PERIOD,
            Bytes(guardian_set_upgrade_3_vaa_bytes()),
        )
        .await;

        let log = response
            .decode_logs_with_type::<ConstructedEvent>()
            .unwrap();
        let event = log.get(0).unwrap();
        assert_eq!(
            *event,
            ConstructedEvent {
                guardian_set_index: 3,
            }
        );

        // Final values
        assert!(
            valid_data_source(
                &deployer.oracle_contract_instance,
                &default_data_sources()[0]
            )
            .await
            .value
        );
        assert_eq!(
            valid_data_sources(&deployer.oracle_contract_instance)
                .await
                .value
                .len(),
            1
        );
        assert_eq!(
            valid_time_period(&deployer.oracle_contract_instance)
                .await
                .value,
            DEFAULT_VALID_TIME_PERIOD
        );
        assert_eq!(
            single_update_fee(&deployer.oracle_contract_instance)
                .await
                .value,
            DEFAULT_SINGLE_UPDATE_FEE
        );
        assert!(
            governance_action_is_consumed(
                &deployer.oracle_contract_instance,
                UPGRADE_3_VAA_GOVERNANCE_ACTION_HASH
            )
            .await
            .value
        );
        assert_eq!(
            current_guardian_set_index(&deployer.oracle_contract_instance,)
                .await
                .value,
            3
        );
        assert_eq!(
            current_wormhole_provider(&deployer.oracle_contract_instance,)
                .await
                .value,
            WormholeProvider {
                governance_chain_id: 1,
                governance_contract: Bits256([
                    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
                    0, 0, 0, 0, 0, 4
                ])
            }
        );
        assert_eq!(
            owner(&deployer.oracle_contract_instance).await.value,
            State::Revoked
        );
    }
}
