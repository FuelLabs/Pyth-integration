use fuels::{
    prelude::{Address, Provider, WalletUnlocked},
    types::Bits256,
};
use pyth_sdk::constants::RPC;
use pyth_sdk::pyth_utils::{
    update_data_bytes, Pyth, BTC_USD_PRICE_FEED_ID, ETH_USD_PRICE_FEED_ID, USDC_USD_PRICE_FEED_ID,
};

#[tokio::main]
async fn main() {
    dotenv::dotenv().ok();

    println!("🔮 Testnet pyth deploy action 🪬 ");

    let provider = Provider::connect(RPC).await.unwrap();

    let admin_pk = std::env::var("ADMIN").unwrap().parse().unwrap();
    let admin = WalletUnlocked::new_from_private_key(admin_pk, Some(provider.clone()));
    println!("Admin address = 0x{}\n", Address::from(admin.address()));

    let pyth = Pyth::deploy(&admin).await;

    pyth.constructor().await;
    let update_data = update_data_bytes(None).await;
    let fee = pyth.update_fee(&update_data).await.value;
    let eth_price_feed = Bits256::from_hex_str(ETH_USD_PRICE_FEED_ID).unwrap();
    let usdc_price_feed = Bits256::from_hex_str(USDC_USD_PRICE_FEED_ID).unwrap();
    let btc_price_feed = Bits256::from_hex_str(BTC_USD_PRICE_FEED_ID).unwrap();
    pyth.update_price_feeds(fee, &update_data).await;
    println!("Pyth address = 0x{:?}\n", pyth.instance.contract_id().hash);
    println!("ETH price {:?}", pyth.price(eth_price_feed).await.value);
    println!("USDC price {:?}", pyth.price(usdc_price_feed).await.value);
    println!("BTC price {:?}", pyth.price(btc_price_feed).await.value);
}
