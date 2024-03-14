use base64::{engine::general_purpose, Engine};
use fuels::{
    prelude::{
        abigen, Bech32ContractId, CallParameters, Contract, LoadConfiguration, TxPolicies,
        WalletUnlocked,
    },
    programs::call_response::FuelCallResponse,
    types::{Address, Bits256, Bytes, Identity},
};
use rand::Rng;

abigen!(Contract(
    name = "PythOracleContract",
    abi = "./pyth-utils/src/abi/pyth-contract-abi.json"
));

pub struct PythInstance {
    pub instance: PythOracleContract<WalletUnlocked>,
    pub wallet: WalletUnlocked,
}

pub const DEFAULT_SINGLE_UPDATE_FEE: u64 = 1;
pub const EXTENDED_TIME_PERIOD: u64 = 3_156_000_000;
pub const GUARDIAN_SET_UPGRADE_3_VAA: &str =
  "01000000020d00ce45474d9e1b1e7790a2d210871e195db53a70ffd6f237cfe70e2686a32859ac43c84a332267a8ef66f59719cf91cc8df0101fd7c36aa1878d5139241660edc0010375cc906156ae530786661c0cd9aef444747bc3d8d5aa84cac6a6d2933d4e1a031cffa30383d4af8131e929d9f203f460b07309a647d6cd32ab1cc7724089392c000452305156cfc90343128f97e499311b5cae174f488ff22fbc09591991a0a73d8e6af3afb8a5968441d3ab8437836407481739e9850ad5c95e6acfcc871e951bc30105a7956eefc23e7c945a1966d5ddbe9e4be376c2f54e45e3d5da88c2f8692510c7429b1ea860ae94d929bd97e84923a18187e777aa3db419813a80deb84cc8d22b00061b2a4f3d2666608e0aa96737689e3ba5793810ff3a52ff28ad57d8efb20967735dc5537a2e43ef10f583d144c12a1606542c207f5b79af08c38656d3ac40713301086b62c8e130af3411b3c0d91b5b50dcb01ed5f293963f901fc36e7b0e50114dce203373b32eb45971cef8288e5d928d0ed51cd86e2a3006b0af6a65c396c009080009e93ab4d2c8228901a5f4525934000b2c26d1dc679a05e47fdf0ff3231d98fbc207103159ff4116df2832eea69b38275283434e6cd4a4af04d25fa7a82990b707010aa643f4cf615dfff06ffd65830f7f6cf6512dabc3690d5d9e210fdc712842dc2708b8b2c22e224c99280cd25e5e8bfb40e3d1c55b8c41774e287c1e2c352aecfc010b89c1e85faa20a30601964ccc6a79c0ae53cfd26fb10863db37783428cd91390a163346558239db3cd9d420cfe423a0df84c84399790e2e308011b4b63e6b8015010ca31dcb564ac81a053a268d8090e72097f94f366711d0c5d13815af1ec7d47e662e2d1bde22678113d15963da100b668ba26c0c325970d07114b83c5698f46097010dc9fda39c0d592d9ed92cd22b5425cc6b37430e236f02d0d1f8a2ef45a00bde26223c0a6eb363c8b25fd3bf57234a1d9364976cefb8360e755a267cbbb674b39501108db01e444ab1003dd8b6c96f8eb77958b40ba7a85fefecf32ad00b7a47c0ae7524216262495977e09c0989dd50f280c21453d3756843608eacd17f4fdfe47600001261025228ef5af837cb060bcd986fcfa84ccef75b3fa100468cfd24e7fadf99163938f3b841a33496c2706d0208faab088bd155b2e20fd74c625bb1cc8c43677a0163c53c409e0c5dfa000100000000000000000000000000000000000000000000000000000000000000046c5a054d7833d1e42000000000000000000000000000000000000000000000000000000000436f7265020000000000031358cc3ae5c097b213ce3c81979e1b9f9570746aa5ff6cb952589bde862c25ef4392132fb9d4a42157114de8460193bdf3a2fcf81f86a09765f4762fd1107a0086b32d7a0977926a205131d8731d39cbeb8c82b2fd82faed2711d59af0f2499d16e726f6b211b39756c042441be6d8650b69b54ebe715e234354ce5b4d348fb74b958e8966e2ec3dbd4958a7cd15e7caf07c4e3dc8e7c469f92c8cd88fb8005a2074a3bf913953d695260d88bc1aa25a4eee363ef0000ac0076727b35fbea2dac28fee5ccb0fea768eaf45ced136b9d9e24903464ae889f5c8a723fc14f93124b7c738843cbb89e864c862c38cddcccf95d2cc37a4dc036a8d232b48f62cdd4731412f4890da798f6896a3331f64b48c12d1d57fd9cbe7081171aa1be1d36cafe3867910f99c09e347899c19c38192b6e7387ccd768277c17dab1b7a5027c0b3cf178e21ad2e77ae06711549cfbb1f9c7a9d8096e85e1487f35515d02a92753504a8d75471b9f49edb6fbebc898f403e4773e95feb15e80c9a99c8348d";

pub fn guardian_set_upgrade_3_vaa_bytes() -> Vec<u8> {
    hex::decode(GUARDIAN_SET_UPGRADE_3_VAA).unwrap()
}

// You can find the ids of prices at https://pyth.network/developers/price-feed-ids#pyth-evm-mainnet
pub const ETH_USD_PRICE_FEED_ID: &str =
    "ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace";
pub const USDC_USD_PRICE_FEED_ID: &str =
    "eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a";
pub const BTC_USD_PRICE_FEED_ID: &str =
    "e62df6c8b4a85fe1a67db44dc12de5db330f7ac66b72dc658afedf0f4a415b43";
pub const UNI_USD_PRICE_FEED_ID: &str =
    "0x78d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501";
pub const FUEL_USD_PRICE_FEED_ID: &str =
    "0x0000000000000000000000000000000000000000000000000000000000000000";

pub fn default_price_feed_ids() -> Vec<Bits256> {
    vec![
        Bits256(
            hex::decode(ETH_USD_PRICE_FEED_ID)
                .unwrap()
                .try_into()
                .unwrap(),
        ),
        Bits256(
            hex::decode(USDC_USD_PRICE_FEED_ID)
                .unwrap()
                .try_into()
                .unwrap(),
        ),
        Bits256(
            hex::decode(BTC_USD_PRICE_FEED_ID)
                .unwrap()
                .try_into()
                .unwrap(),
        ),
    ]
}

pub async fn _update_data_bytes() -> Vec<Bytes> {
    let c = reqwest::Client::new();
    let req = format!("https://hermes.pyth.network/api/latest_vaas?ids[]={ETH_USD_PRICE_FEED_ID}&ids[]={USDC_USD_PRICE_FEED_ID}&ids[]={BTC_USD_PRICE_FEED_ID}");
    let body = c.get(req).send().await.unwrap().text().await.unwrap();
    let responce: [&str; 3] = serde_json::from_str(body.as_str()).unwrap();
    responce
        .iter()
        .map(|data| {
            Bytes(
                general_purpose::STANDARD
                    .decode::<&str>(data)
                    .unwrap()
                    .clone(),
            )
        })
        .collect()
}

pub fn default_update_data_bytes() -> Vec<Bytes> {
    let responce = ["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"];
    responce
        .iter()
        .map(|data| {
            Bytes(
                general_purpose::STANDARD
                    .decode::<&str>(data)
                    .unwrap()
                    .clone(),
            )
        })
        .collect()
}

impl PythInstance {
    pub async fn price(&self, price_feed_id: Bits256) -> FuelCallResponse<Price> {
        self.instance
            .methods()
            .price(price_feed_id)
            .simulate()
            .await
            .unwrap()
    }

    pub async fn update_price_feeds(
        &self,
        fee: u64,
        update_data: &Vec<Bytes>,
    ) -> FuelCallResponse<()> {
        self.instance
            .methods()
            .update_price_feeds(update_data.to_vec())
            .call_params(CallParameters::default().with_amount(fee))
            .unwrap()
            .call()
            .await
            .unwrap()
    }

    pub async fn update_fee(&self, update_data: &Vec<Bytes>) -> FuelCallResponse<u64> {
        self.instance
            .methods()
            .update_fee(update_data.to_vec())
            .simulate()
            .await
            .unwrap()
    }

    pub async fn constructor(&self) -> FuelCallResponse<()> {
        self.instance
            .methods()
            .constructor(
                default_data_sources(),
                DEFAULT_SINGLE_UPDATE_FEE,
                EXTENDED_TIME_PERIOD,
                Bytes(guardian_set_upgrade_3_vaa_bytes()),
            )
            .with_tx_policies(TxPolicies::default().with_gas_price(1))
            .call()
            .await
            .unwrap()
    }

    pub fn new(wallet: &WalletUnlocked, id: &Bech32ContractId) -> Self {
        Self {
            instance: PythOracleContract::new(id, wallet.clone()),
            wallet: wallet.clone(),
        }
    }

    pub async fn deploy(wallet: &WalletUnlocked) -> Self {
        let mut rng = rand::thread_rng();
        let salt = rng.gen::<[u8; 32]>();
        let configurables = PythOracleContractConfigurables::default()
            .with_DEPLOYER(Identity::Address(Address::from(wallet.address())));
        let config = LoadConfiguration::default().with_configurables(configurables);

        let id = Contract::load_from("tests/artefacts/pyth/pyth-contract.bin", config)
            .unwrap()
            .with_salt(salt)
            .deploy(wallet, TxPolicies::default().with_gas_price(1))
            .await
            .unwrap();

        Self {
            instance: PythOracleContract::new(id, wallet.clone()),
            wallet: wallet.clone(),
        }
    }
}
// data sources from Pyth EVM deployment docs:
// https://github.com/pyth-network/pyth-crosschain/blob/2008da7a451231489d9866d7ceae3799c07e1fb5/contract_manager/src/base.ts#L116
pub fn default_data_sources() -> Vec<DataSource> {
    vec![
        DataSource {
            chain_id: 1,
            emitter_address: Bits256::from_hex_str(
                "6bb14509a612f01fbbc4cffeebd4bbfb492a86df717ebe92eb6df432a3f00a25",
            )
            .unwrap(),
        },
        DataSource {
            chain_id: 26,
            emitter_address: Bits256::from_hex_str(
                "f8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba0",
            )
            .unwrap(),
        },
        DataSource {
            chain_id: 26,
            emitter_address: Bits256::from_hex_str(
                "e101faedac5851e32b9b23b5f9411a8c2bac4aae3ed4dd7b811dd1a72ea4aa71",
            )
            .unwrap(),
        },
        DataSource {
            chain_id: 1,
            emitter_address: Bits256::from_hex_str(
                "f346195ac02f37d60d4db8ffa6ef74cb1be3550047543a4a9ee9acf4d78697b0",
            )
            .unwrap(),
        },
        DataSource {
            chain_id: 26,
            emitter_address: Bits256::from_hex_str(
                "a27839d641b07743c0cb5f68c51f8cd31d2c0762bec00dc6fcd25433ef1ab5b6",
            )
            .unwrap(),
        },
    ]
}
