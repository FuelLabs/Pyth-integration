use fuels::{prelude::*, types::ContractId};

// Load abi from json
abigen!(Contract(
    name = "MyContract",
    abi = "./pyth-contract/out/debug/pyth-contract-abi.json"
));

async fn get_contract_instance() -> (MyContract<WalletUnlocked>, ContractId) {
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
    let wallet = wallets.pop().unwrap();

    let storage_config =
        StorageConfiguration::load_from("./out/debug/pyth-contract-storage_slots.json").unwrap();

    let load_config = LoadConfiguration::default().with_storage_configuration(storage_config);

    let id = Contract::load_from("./out/debug/pyth-contract.bin", load_config)
        .unwrap()
        .deploy(&wallet, TxParameters::default())
        .await
        .unwrap();

    let instance = MyContract::new(id.clone(), wallet);

    (instance, id.into())
}

#[tokio::test]
async fn can_get_contract_id() {
    let (_instance, id) = get_contract_instance().await;

    println!("{id}");

    // Now you have an instance of your contract you can use to test each function
}
