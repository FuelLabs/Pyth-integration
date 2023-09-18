use fuels::{
    prelude::*,
    types::{Bits256, ContractId},
};

// Load abi from json
abigen!(Contract(
    name = "PythOracleContract",
    abi = "./pyth-contract/out/debug/pyth-contract-abi.json"
));

const ORACLE_CONTRACT_BINARY_PATH: &str = "./out/debug/pyth-contract.bin";
const ORACLE_CONTRACT_STORAGE_PATH: &str = "./out/debug/pyth-contract-storage_slots.json";

pub(crate) const DEFAULT_DATA_SOURCE_CHAIN_ID: u16 = 1;
pub(crate) const DEFAULT_DATA_SOURCE_EMITTER_ADDRESS: &str =
    "0x71f8dcb863d176e2c420ad6610cf687359612b6fb392e0642b0ca6b1f186aa3b";
pub(crate) const DEFAULT_SINGLE_UPDATE_FEE: u64 = 1;
pub(crate) const DEFAULT_VALID_TIME_PERIOD: u64 = 60;
const GUARDIAN_SET_UPGRADE_3_VAA: &str =
  "01000000020d00ce45474d9e1b1e7790a2d210871e195db53a70ffd6f237cfe70e2686a32859ac43c84a332267a8ef66f59719cf91cc8df0101fd7c36aa1878d5139241660edc0010375cc906156ae530786661c0cd9aef444747bc3d8d5aa84cac6a6d2933d4e1a031cffa30383d4af8131e929d9f203f460b07309a647d6cd32ab1cc7724089392c000452305156cfc90343128f97e499311b5cae174f488ff22fbc09591991a0a73d8e6af3afb8a5968441d3ab8437836407481739e9850ad5c95e6acfcc871e951bc30105a7956eefc23e7c945a1966d5ddbe9e4be376c2f54e45e3d5da88c2f8692510c7429b1ea860ae94d929bd97e84923a18187e777aa3db419813a80deb84cc8d22b00061b2a4f3d2666608e0aa96737689e3ba5793810ff3a52ff28ad57d8efb20967735dc5537a2e43ef10f583d144c12a1606542c207f5b79af08c38656d3ac40713301086b62c8e130af3411b3c0d91b5b50dcb01ed5f293963f901fc36e7b0e50114dce203373b32eb45971cef8288e5d928d0ed51cd86e2a3006b0af6a65c396c009080009e93ab4d2c8228901a5f4525934000b2c26d1dc679a05e47fdf0ff3231d98fbc207103159ff4116df2832eea69b38275283434e6cd4a4af04d25fa7a82990b707010aa643f4cf615dfff06ffd65830f7f6cf6512dabc3690d5d9e210fdc712842dc2708b8b2c22e224c99280cd25e5e8bfb40e3d1c55b8c41774e287c1e2c352aecfc010b89c1e85faa20a30601964ccc6a79c0ae53cfd26fb10863db37783428cd91390a163346558239db3cd9d420cfe423a0df84c84399790e2e308011b4b63e6b8015010ca31dcb564ac81a053a268d8090e72097f94f366711d0c5d13815af1ec7d47e662e2d1bde22678113d15963da100b668ba26c0c325970d07114b83c5698f46097010dc9fda39c0d592d9ed92cd22b5425cc6b37430e236f02d0d1f8a2ef45a00bde26223c0a6eb363c8b25fd3bf57234a1d9364976cefb8360e755a267cbbb674b39501108db01e444ab1003dd8b6c96f8eb77958b40ba7a85fefecf32ad00b7a47c0ae7524216262495977e09c0989dd50f280c21453d3756843608eacd17f4fdfe47600001261025228ef5af837cb060bcd986fcfa84ccef75b3fa100468cfd24e7fadf99163938f3b841a33496c2706d0208faab088bd155b2e20fd74c625bb1cc8c43677a0163c53c409e0c5dfa000100000000000000000000000000000000000000000000000000000000000000046c5a054d7833d1e42000000000000000000000000000000000000000000000000000000000436f7265020000000000031358cc3ae5c097b213ce3c81979e1b9f9570746aa5ff6cb952589bde862c25ef4392132fb9d4a42157114de8460193bdf3a2fcf81f86a09765f4762fd1107a0086b32d7a0977926a205131d8731d39cbeb8c82b2fd82faed2711d59af0f2499d16e726f6b211b39756c042441be6d8650b69b54ebe715e234354ce5b4d348fb74b958e8966e2ec3dbd4958a7cd15e7caf07c4e3dc8e7c469f92c8cd88fb8005a2074a3bf913953d695260d88bc1aa25a4eee363ef0000ac0076727b35fbea2dac28fee5ccb0fea768eaf45ced136b9d9e24903464ae889f5c8a723fc14f93124b7c738843cbb89e864c862c38cddcccf95d2cc37a4dc036a8d232b48f62cdd4731412f4890da798f6896a3331f64b48c12d1d57fd9cbe7081171aa1be1d36cafe3867910f99c09e347899c19c38192b6e7387ccd768277c17dab1b7a5027c0b3cf178e21ad2e77ae06711549cfbb1f9c7a9d8096e85e1487f35515d02a92753504a8d75471b9f49edb6fbebc898f403e4773e95feb15e80c9a99c8348d";
pub(crate) const UPGRADE_3_VAA_GOVERNANCE_ACTION_HASH: Bits256 = Bits256([
    217, 239, 119, 23, 11, 244, 8, 47, 149, 67, 246, 0, 76, 60, 57, 207, 198, 14, 21, 100, 172,
    111, 192, 147, 192, 75, 95, 51, 126, 151, 234, 51,
]);

pub(crate) struct Caller {
    pub(crate) oracle_contract_instance: PythOracleContract<WalletUnlocked>,
    pub(crate) wallet: WalletUnlocked,
}

pub(crate) async fn setup_environment() -> (ContractId, Caller) {
    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(1),             /* Single wallet */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        None,
        None,
    )
    .await;
    let deployer_wallet = wallets.pop().unwrap();

    let storage_config = StorageConfiguration::load_from(ORACLE_CONTRACT_STORAGE_PATH).unwrap();

    let load_config = LoadConfiguration::default().with_storage_configuration(storage_config);

    let id = Contract::load_from(ORACLE_CONTRACT_BINARY_PATH, load_config)
        .unwrap()
        .deploy(&deployer_wallet, TxParameters::default())
        .await
        .unwrap();

    let deployer = Caller {
        oracle_contract_instance: PythOracleContract::new(id.clone(), deployer_wallet.clone()),
        wallet: deployer_wallet,
    };

    (id.into(), deployer)
}

pub(crate) fn guardian_set_upgrade_3_vaa_bytes() -> Vec<u8> {
    hex::decode(GUARDIAN_SET_UPGRADE_3_VAA).unwrap()
}
