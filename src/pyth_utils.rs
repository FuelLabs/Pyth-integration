use std::path::PathBuf;

use base64::{
    engine::general_purpose,
    prelude::{Engine, BASE64_STANDARD},
};
use fuels::{
    prelude::{abigen, CallParameters, Contract, LoadConfiguration, TxPolicies, WalletUnlocked},
    programs::call_response::FuelCallResponse,
    types::{Address, Bits256, Bytes, Identity},
};
use rand::Rng;

abigen!(Contract(
    name = "PythOracleContract",
    abi = "pyth-contract/out/debug/pyth-contract-abi.json"
));

pub struct Pyth {
    pub instance: PythOracleContract<WalletUnlocked>,
    pub wallet: WalletUnlocked,
}

const ORACLE_CONTRACT_BINARY_PATH: &str = "./pyth-contract/out/debug/pyth-contract.bin";

pub const DEFAULT_SINGLE_UPDATE_FEE: u64 = 1;
pub const DEFAULT_VALID_TIME_PERIOD: u64 = 60;
pub const EXTENDED_TIME_PERIOD: u64 = 3_156_000_000;
pub const GUARDIAN_SET_UPGRADE_3_VAA: &str =
  "01000000020d00ce45474d9e1b1e7790a2d210871e195db53a70ffd6f237cfe70e2686a32859ac43c84a332267a8ef66f59719cf91cc8df0101fd7c36aa1878d5139241660edc0010375cc906156ae530786661c0cd9aef444747bc3d8d5aa84cac6a6d2933d4e1a031cffa30383d4af8131e929d9f203f460b07309a647d6cd32ab1cc7724089392c000452305156cfc90343128f97e499311b5cae174f488ff22fbc09591991a0a73d8e6af3afb8a5968441d3ab8437836407481739e9850ad5c95e6acfcc871e951bc30105a7956eefc23e7c945a1966d5ddbe9e4be376c2f54e45e3d5da88c2f8692510c7429b1ea860ae94d929bd97e84923a18187e777aa3db419813a80deb84cc8d22b00061b2a4f3d2666608e0aa96737689e3ba5793810ff3a52ff28ad57d8efb20967735dc5537a2e43ef10f583d144c12a1606542c207f5b79af08c38656d3ac40713301086b62c8e130af3411b3c0d91b5b50dcb01ed5f293963f901fc36e7b0e50114dce203373b32eb45971cef8288e5d928d0ed51cd86e2a3006b0af6a65c396c009080009e93ab4d2c8228901a5f4525934000b2c26d1dc679a05e47fdf0ff3231d98fbc207103159ff4116df2832eea69b38275283434e6cd4a4af04d25fa7a82990b707010aa643f4cf615dfff06ffd65830f7f6cf6512dabc3690d5d9e210fdc712842dc2708b8b2c22e224c99280cd25e5e8bfb40e3d1c55b8c41774e287c1e2c352aecfc010b89c1e85faa20a30601964ccc6a79c0ae53cfd26fb10863db37783428cd91390a163346558239db3cd9d420cfe423a0df84c84399790e2e308011b4b63e6b8015010ca31dcb564ac81a053a268d8090e72097f94f366711d0c5d13815af1ec7d47e662e2d1bde22678113d15963da100b668ba26c0c325970d07114b83c5698f46097010dc9fda39c0d592d9ed92cd22b5425cc6b37430e236f02d0d1f8a2ef45a00bde26223c0a6eb363c8b25fd3bf57234a1d9364976cefb8360e755a267cbbb674b39501108db01e444ab1003dd8b6c96f8eb77958b40ba7a85fefecf32ad00b7a47c0ae7524216262495977e09c0989dd50f280c21453d3756843608eacd17f4fdfe47600001261025228ef5af837cb060bcd986fcfa84ccef75b3fa100468cfd24e7fadf99163938f3b841a33496c2706d0208faab088bd155b2e20fd74c625bb1cc8c43677a0163c53c409e0c5dfa000100000000000000000000000000000000000000000000000000000000000000046c5a054d7833d1e42000000000000000000000000000000000000000000000000000000000436f7265020000000000031358cc3ae5c097b213ce3c81979e1b9f9570746aa5ff6cb952589bde862c25ef4392132fb9d4a42157114de8460193bdf3a2fcf81f86a09765f4762fd1107a0086b32d7a0977926a205131d8731d39cbeb8c82b2fd82faed2711d59af0f2499d16e726f6b211b39756c042441be6d8650b69b54ebe715e234354ce5b4d348fb74b958e8966e2ec3dbd4958a7cd15e7caf07c4e3dc8e7c469f92c8cd88fb8005a2074a3bf913953d695260d88bc1aa25a4eee363ef0000ac0076727b35fbea2dac28fee5ccb0fea768eaf45ced136b9d9e24903464ae889f5c8a723fc14f93124b7c738843cbb89e864c862c38cddcccf95d2cc37a4dc036a8d232b48f62cdd4731412f4890da798f6896a3331f64b48c12d1d57fd9cbe7081171aa1be1d36cafe3867910f99c09e347899c19c38192b6e7387ccd768277c17dab1b7a5027c0b3cf178e21ad2e77ae06711549cfbb1f9c7a9d8096e85e1487f35515d02a92753504a8d75471b9f49edb6fbebc898f403e4773e95feb15e80c9a99c8348d";
pub const UPGRADE_3_VAA_GOVERNANCE_ACTION_HASH: Bits256 = Bits256([
    217, 239, 119, 23, 11, 244, 8, 47, 149, 67, 246, 0, 76, 60, 57, 207, 198, 14, 21, 100, 172,
    111, 192, 147, 192, 75, 95, 51, 126, 151, 234, 51,
]);

/*
You can find the ids of prices at https://pyth.network/developers/price-feed-ids#pyth-evm-mainnet

DEFAULT_BATCH_UPDATE_DATA is the corresponding update data for an update of the following price feeds prior to Pyth's Hermes service upgrade,
DEFAULT_ACCUMULATOR_UPDATE_DATA is the corresponding update data for an update of the following price feeds after to Pyth's Hermes service upgrade,
ETH/USD mainnet with id: "0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace"
USDC/USD mainnet with id: "0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a"
*/
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
const DEFAULT_BATCH_UPDATE_DATA: [&str; 2] = [
        "01000000030d001b51e4d946d35c7e77f340611d0047b11a46366c21743aa1ab3485c5dc8d5ba50ddbb50072711d6e324357d0b46147e836c46d7127b1bdcea00e63bd6864d0b40002591ec14b695200a82e701088db6d24f9704094e9bf60751d96d21d5cd858c16c5371555bf86fa59055ca718cd27be45a6a0db16b471429442e5b7353aa0755120003b6d17e1c2131a136252c0cfeb846db6f997bf7da30fb27dc285de7406dfeaed97bdd63bef8042fa3455668d1f080ad2b244965754b06b097b13eccd000e46b6601047fd025f1e5e44fcef994c0c029c6c60a9ea2cec9c022e13aca5386d0fb7e084f48a03d1b85435860bf7dde210c0b2a2005707d4969307a05c42ef6c8c1fd113701081e65c223a9384526322fe3bcbddf03c35957ad448b31d7ab0575e164ba7d0e6d2394730d94ca133b1a297ee6a3592239a5fc26217c959a8e1167328a364664360109b76655ee19d1910c10acbde342be029012c5e5e133fd0dbdd3b19202c44131e1611fd8c58b7843e724ef18120bada8526a71587e5833c99d0c1ee5f8580b3c80010aba9cce6c143e232a2014d580d1d3ab6a679981cfd2c840e28a6e51b01f6d64f73e25bdfc9c63cab59e952519edda2c93ffd601ee89da8dd209409ce9bd4adea3010b939cb7c58868161e2822b6f8baef4b78c309c2e2cbec4dd7386fa2631843b5a231c394ba40ac2acece38469a2c668ac3c17d8c0f7cf67e03d2ea6694fe41f924010ce831c72700cb7eac40fbbe26dcec71b825fa12ed5235f629c075153f53fbcf3b58dcfabd84630cd53db705f101f2b74053b2a99f2ea6e40d243c99cb058424b9010d5855a6d1545239ed62b2cb4f1d3eb05b5da87b19b0ccc42a8a00429823a6527558d3378eab625d8300f5dbd4a82efe6aa01cc5f30c92a48c62881a87c1c970cc010e961968172f030819b64f45b7291b10b7463ef35c2aafc5fe09cfa1ea1657c354789e7f58292873058b47698b97335727da139513a1d1648a2a97fd4992da3b950110876b85ed65413cd49769b5d89fd17006fa2bd6e587de87002304c292b720862f4ee734acbd764e32737875df7904d582ba8a36675aad9b5a03559208e7801e300012689def292c14780b6472950c9108ab89e8f96e59a678bad94299636f02942ab87a63d2a25ed7bf4cd734ff0b6c151addbafc717c1eacd63d777b154b2d4a451d016509ac2200000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba00000000027b2eea40150325748000300010001020005009d04028fba493a357ecde648d51375a445ce1cb9681da1ea11e562b53522a5d3877f981f906d7cfe93f618804f1de89e0199ead306edc022d3230b3e8305f391b0000000262d381a2d000000000d27fd0ffffffff800000026402959a80000000008e750f8010000000c0000000f000000006509ac22000000006509ac22000000006509ac21000000262d381a2d000000000d27fd0f000000006509ac20e6c020c1a15366b779a8c870e065023657c88c82b82d58a9fe856896a4034b0415ecddd26d49e1a8f1de9376ebebc03916ede873447c1255d2d5891b92ce57170000002813f5221f000000000eb8d8e0fffffff8000000282adca8a0000000000d0922e6010000000a0000000d000000006509ac22000000006509ac22000000006509ac210000002813f3b3e9000000000eb76aaa000000006509ac20c67940be40e0cc7ffaa1acb08ee3fab30955a197da1ec297ab133d4d43d86ee6ff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace0000002634584af800000000042d0d26fffffff80000002646b141780000000003885c6e010000001c00000020000000006509ac22000000006509ac22000000006509ac2100000026344f4b2c0000000003f7ac6e000000006509ac218d7c0971128e8a4764e757dedb32243ed799571706af3a68ab6a75479ea524ff846ae1bdb6300b817cee5fdee2a6da192775030db5615b94a465f53bd40850b50000002630681286000000000db7d7d4fffffff80000002642d956a8000000000a25111c010000000d0000000e000000006509ac22000000006509ac21000000006509ac210000002630681286000000000bd82220000000006509ac20543b71a4c292744d3fcf814a2ccda6f7c00f283d457f83aa73c41e9defae034ba0255134973f4fdf2f8f7808354274a3b1ebc6ee438be898d045e8b56ba1fe1300000000000000000000000000000000fffffff800000000000000000000000000000000000000000400000008000000006509ac22000000006509ac210000000000000000000000000000000000000000000000000000000000000000",
        "01000000030d0022aaaa4bd962a5d265c95bf56be1940d78d10c4b06a8e6ca96cf45dae7f9ddc03790489a5d223fa491cfd90b2d8e4be190be02beefa0387593205c8c8e3f238f0102c509f97882083f6a960a01ff11e55c729c7c1e2c74dba40d5a3cd4cc7f2afcc4491032211d48dba44f7ce4fbd91c1eb0845083f961519bb50af3913159c55e910003da8bdfb35391a072450e03fa019f3b9fdc2971ebf55b24d334956097b863686e4be02b244570a91088433b8af9d774ea22659079cc62bc97bd15486c488bca55010455bbc59a4463198852702cc92fb40af92b440bd63ec119d96663dffe13f4204a5e41b7711a996852ea0a8ff6ddb5679078de0fd257dbd9246effaf921da951f400083363c6ba4a683820a8246485daa82cdb76571e01cc52d31c8198b921102da4850da23eda6b080b8b9b50981e8a042037a2eb081ab2cd0560b1419843c7b722740109ead0fe09278b8f9a64647323734fc72c061565145a137d31eb988a4847bcbdca2168f245506581438c08fad54a9b4e3b82441a8784286d9d388cb20acc84956a010a64ff6a9138bbaa73290ee69676b6f0c29ce546185eee4e241c290af271a7c9690b6320a16b33a5e11a8906f69ac3c81b9fe564ad9bc98168407a1e4a521b8547010beb43c832acae9374910109d00c6bb163ef67ac252f13486472874ff0415346ae6cfbb6899cfba138f0d932574de9d44f8e03d9e07907b5d16c75f915e1d9be96000c123460082f0aad0f5afb570d88e9931f08f484ef307642a6ff4a7d21a628778a180db29ea06e36acd94a8a2272b9ccc05af96258a9c3cb3cb78fbe3e73d7b3a1000d9c90528b9a87ea7f095076be9290b526ee2794b44032f6f86935d335707a0b0c1566953d31e317e558766123c3904c5dbf9a0a193598c34c8852be20bf595a38000e01b5aef758c7d4124439888bed8a560dbd78e94cdc0a5e4fd39a95bab39aa64977c6b7dab96253420dd473a87c37d951f96131112e9bbc9f81b4fe56e040f51c0010cae1df6dad0a236786aae2f22668d921b9b1d09ba2ef74f0214f0a3055ec1d913fac9e1c7c33338443aeb92e16f59bbabda44da77bbbaa5766ccac2b93da119c011265e001640ed56620f638102e240716bfd66435131b370b92fb0cbb39493c4ffe417dacc48982831040ce5cfe8f3c278bd16c3bbdc8b300e53e8ddb020bc2d6fd006509ac2200000000001af8cd23c2ab91237730770bbea08d61005cdda0984348f3f6eecb559638c0bba00000000027b2ee9d0150325748000300010001020005009db0e13ce3260d884b0417c6b4d152d45b2f13991a8592522fad0068a4bce3dfbdf0d57deca57b3da2fe63a493f4c25925fdfd8edf834b20f93e1f84dbd1504d4a0000000000011fbc000000000000005ffffffff6000000000001209e0000000000000068010000001100000016000000006509ac22000000006509ac22000000006509ac210000000000011fbc000000000000005f000000006509ac218ab03cff1844ab975dcdd1683020c0599fc5392b6f2e12d5dd615bcc2c2e6d08ef0d8b6fda2ceba41da15d4095d1da392a0d2f8ed0c6c7bc0f4cfac8c280b56d0000000076e1a7a00000000000189196fffffff800000000774edb860000000000167db6010000001a00000020000000006509ac22000000006509ac22000000006509ac210000000076e18bf400000000001875ea000000006509ac21127ab385f079cf02de5a6c0bc8414267acd086fd268730caf319e86b88d2342923d7315113f5b1d3ba7a83604c44b94d79f4fd69af77f804fc7f920a6dc657440000000002ac7a6d000000000000b6cafffffff80000000002b09148000000000000840b010000001200000015000000006509ac22000000006509ac22000000006509ac210000000002ac8bb30000000000009068000000006509ac21c12e5d198c9c673e9ce03265e7d9be69cd6a0c674aabd3d2c41ff5764023e22878d185a741d07edb3412b09008b7c5cfb9bbbd7d568bf00ba737b456ba171501000000001a54d4420000000000045e4dfffffff8000000001a699208000000000004825201000000180000001d000000006509ac22000000006509ac22000000006509ac21000000001a54d44200000000000459ad000000006509ac216bfad3ab2ad6ed59591a5a77cc9b162f8e228e89ef56151b24e15426a2bb4d48eaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a0000000005f5e54c0000000000005463fffffff80000000005f5e09000000000000053af01000000160000001b000000006509ac22000000006509ac22000000006509ac210000000005f5e54c0000000000005463000000006509ac21"
      ];
const DEFAULT_ACCUMULATOR_UPDATE_DATA: &str = "UE5BVQEAAAADuAEAAAADDQHZQAkib294P0wA9HaAI75z6ADW9Deb8xoQhCQPldh3SW1cpUtnWXAPoseiiFU+GD93EUWFbiwjj8x2i4u9dVDGAAJzve5v2O//gbEkRkblLOSgNyCcgi/zMjgJCfF/XBR9igeBr9QqRn8AiJyYsVKQj2FEKjFvJB1M4qKf2AkmtEC0AQO3K1z4+7M6aSxlZOu8v37HLizCShleOXY8/R3AgwWEsD1cy6cS4lzAByc5O4MD4SXS70AlPAyLy+fyzgPjsg2sAAS8g7z6C/VZ/oRFA10H5XmIN6AtS5vtTmv5GRadDvzf43Z23XjXjCygg27qzAH2/p6pe7PsXGgEB7LZtb097W7SAAbV56MzblHOQK1wWaTnNK7YOeEbzY5/qRt2WRIWoETqRV+fiYbsAaiKvScBiWMZoG6cF1WUpqMIa6OWPHXDUoGbAAiAAb/uLRAJ0FQm9petvB5T0tA+ijPYPz1RrgymnVdw8UerbCEOO5f8oUfIbvva2piyZbDENn67wXShZnI8pm4aAQmVdkk5kCj2UGq5GbH+j9md0HjZAs3mxu0SwK6XQ/gFiFdB3ksY1epYjHFowD/cTOU22B9jem3XHGNN64LuHU+DAQrhtog708Yt+mOhnBHq5VbH0DNxUi3rrC2WDndm6fr9EHt5kvovIXGdEAKEJIy8V71cRM9JnhqEfAQgqJGBDc8NAAsMt3qBcV5O3dTfPGbQ4B7YrfYP0qBrTkCorWRHHcdzAkDUvJg8/rVe5BSgvsv85b7Wc5LRLl9D91tKn1/5Nr8lAA30nswq/fUgnM9YGgLRk9Q3VjiQM05zi1o4nHSQam+naHTUTLjUdG9muhL5D9Sm87h4KeHsSLGcm10Z3ALyTuR6AA5/3Fxn3OATaNnX9Q5zaodPWACqTjeqDdhX9nsDCCg/kVzDTwCLV8rMN/5zNIuW+6B5IxCefoHWr3wTaBDOH4pRARBQwSVI79R1oqOD9Q0I6aEw9YiZzndgICAUgm1s0XQmrnIPXILg1S6U5SBmbmasFrmuQjzyT2bfQEFepdSkBtL4ARIJBhwqP7cCcN54bRO8BFMf9uggBwefvAOItjHlmeD6cyCd/AdNazo+yzxQ8OySX1fSV/KWR3HgZAa9sFiqQkioAGX3kJ8AAAAAABrhAfrtrFhR4yubI7X5QRqMK6xKrj7U3XuBHdGnLqSqcQAAAAACt7PmAUFVV1YAAAAAAAfA4lsAACcQFs+MLyt9WTDbgrvDKemEA77GspsCAFUA/2FJGpMREt3xvYFHzRtkE3X3n1glEm1mVICHRjT9Cs4AAABTdXi3FQAAAAAbBdyL////+AAAAABl95CfAAAAAGX3kJ4AAABUeMdMYAAAAAASjyFCCks8cVh/PJ9xfgCM9x3FsIMJFnVjEojlpG4imZK2XyO5bhjP67ysp68K0jfHqXjoX7/R/9iprYZp9MU1kFh3kyVHUfL13SuiDfJ7x488z0p+mmzfGV82Ulra0F+wmHjnxOjmL3nvCVi1kpNBqIyxTT4C2LO6A2bzQDLc8lu//y0pCITlbnUPUX8kEURLGMKLvl4AZCouKhEf96WVLn4J0afYAg4rr0e2N5cE8Nrc9eFIRbfhPtf+Tq3bZD2Cz195wosYubVUAhrqAFUA6qAgxhzEeXEoE0Yc4VOJSpamwAsh7Qz8J5jR+anpyUoAAAAABfZfVQAAAAAAASks////+AAAAABl95CfAAAAAGX3kJ4AAAAABfYthQAAAAAAAQapCsekl7cD3r9Brv2cv2oRm84XAtQ1lrUyNMk8O0VT1BZIvTc7XvsLBV7yjN9+xITbLFqrASPD1onPE2frSTSVfSAWUEUBg/PldOce8OVmbQYhbysX8dzRdX9qDVlMc5wNYrzmKVINKXl+6z85upK8FFj9yD+civPT6E3qQUn0Zun7naDPhIRVDsnlP8vSGMKLvl4AZCouKhEf96WVLn4J0afYAg4rr0e2N5cE8Nrc9eFIRbfhPtf+Tq3bZD2Cz195wosYubVUAhrq";

pub async fn update_data_bytes() -> Vec<Bytes> {
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

pub fn default_batch_update_data_bytes() -> Vec<Bytes> {
    DEFAULT_BATCH_UPDATE_DATA
        .iter()
        .map(|update| Bytes(hex::decode(update).unwrap()))
        .collect()
}

pub fn default_accumulator_update_data_bytes() -> Vec<Bytes> {
    vec![Bytes(
        BASE64_STANDARD
            .decode(DEFAULT_ACCUMULATOR_UPDATE_DATA)
            .unwrap(),
    )]
}

impl Pyth {
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

    pub async fn deploy(wallet: &WalletUnlocked) -> Self {
        let mut rng = rand::thread_rng();
        let salt = rng.gen::<[u8; 32]>();
        let configurables = PythOracleContractConfigurables::default()
            .with_DEPLOYER(Identity::Address(Address::from(wallet.address())));
        let config = LoadConfiguration::default().with_configurables(configurables);

        let id = Contract::load_from(
            PathBuf::from(env!("CARGO_MANIFEST_DIR")).join(ORACLE_CONTRACT_BINARY_PATH),
            config,
        )
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

pub fn guardian_set_upgrade_3_vaa_bytes() -> Vec<u8> {
    hex::decode(GUARDIAN_SET_UPGRADE_3_VAA).unwrap()
}

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
    ]
}

// price feeds from Pyth network at the time of the DEFAULT_BATCH_UPDATE_DATA
pub const BATCH_ETH_USD_PRICE_FEED: PriceFeed = PriceFeed {
    ema_price: Price {
        confidence: 59268206,
        exponent: 8,
        price: 164394779000,
        publish_time: 4611686020122520610,
    },
    id: Bits256([
        255, 97, 73, 26, 147, 17, 18, 221, 241, 189, 129, 71, 205, 27, 100, 19, 117, 247, 159, 88,
        37, 18, 109, 102, 84, 128, 135, 70, 52, 253, 10, 206,
    ]),
    price: Price {
        confidence: 70061350,
        exponent: 8,
        price: 164086958840,
        publish_time: 4611686020122520610,
    },
};
pub const BATCH_USDC_USD_PRICE_FEED: PriceFeed = PriceFeed {
    ema_price: Price {
        confidence: 21423,
        exponent: 8,
        price: 99999888,
        publish_time: 4611686020122520610,
    },
    id: Bits256([
        234, 160, 32, 198, 28, 196, 121, 113, 40, 19, 70, 28, 225, 83, 137, 74, 150, 166, 192, 11,
        33, 237, 12, 252, 39, 152, 209, 249, 169, 233, 201, 74,
    ]),
    price: Price {
        confidence: 21603,
        exponent: 8,
        price: 100001100,
        publish_time: 4611686020122520610,
    },
};

// price feeds from Pyth network at the time of the DEFAULT_ACCUMULATOR_UPDATE_DATA
pub const ACCUMULATOR_ETH_USD_PRICE_FEED: PriceFeed = PriceFeed {
    ema_price: Price {
        confidence: 311370050,
        exponent: 8,
        price: 362803580000,
        publish_time: 4611686020138111135,
    },
    id: Bits256([
        255, 97, 73, 26, 147, 17, 18, 221, 241, 189, 129, 71, 205, 27, 100, 19, 117, 247, 159, 88,
        37, 18, 109, 102, 84, 128, 135, 70, 52, 253, 10, 206,
    ]),
    price: Price {
        confidence: 453368971,
        exponent: 8,
        price: 358453131029,
        publish_time: 4611686020138111135,
    },
};
pub const ACCUMULATOR_USDC_USD_PRICE_FEED: PriceFeed = PriceFeed {
    ema_price: Price {
        confidence: 67241,
        exponent: 8,
        price: 100019589,
        publish_time: 4611686020138111135,
    },
    id: Bits256([
        234, 160, 32, 198, 28, 196, 121, 113, 40, 19, 70, 28, 225, 83, 137, 74, 150, 166, 192, 11,
        33, 237, 12, 252, 39, 152, 209, 249, 169, 233, 201, 74,
    ]),
    price: Price {
        confidence: 76076,
        exponent: 8,
        price: 100032341,
        publish_time: 4611686020138111135,
    },
};
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
