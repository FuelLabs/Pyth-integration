use fuels::{
    prelude::{Address, Provider, WalletUnlocked},
    types::Bits256,
};
use pyth_sdk::constants::BETA_5_URL;
use pyth_sdk::{
    constants::{BTC_USD_PRICE_FEED_ID, ETH_USD_PRICE_FEED_ID, USDC_USD_PRICE_FEED_ID},
    pyth_utils::{update_data_bytes, Pyth},
};

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv::dotenv().ok();

    println!("🔮 Testnet Pyth deploy action");

    let provider = Provider::connect(BETA_5_URL).await?;

    let admin_pk = std::env::var("ADMIN").expect("ADMIN environment variable missing");
    let admin = WalletUnlocked::new_from_private_key(admin_pk.parse()?, Some(provider.clone()));
    println!("Admin address = 0x{}\n", Address::from(admin.address()));

    let pyth = Pyth::deploy(admin).await?;

    let _ = pyth.constructor().await;

    let update_data = update_data_bytes(None).await?;
    let fee = pyth.update_fee(&update_data).await?.value;

    let btc_price_feed = Bits256::from_hex_str(BTC_USD_PRICE_FEED_ID)?;
    let eth_price_feed = Bits256::from_hex_str(ETH_USD_PRICE_FEED_ID)?;
    let usdc_price_feed = Bits256::from_hex_str(USDC_USD_PRICE_FEED_ID)?;

    let _ = pyth.update_price_feeds(fee, &update_data).await;

    println!("Pyth address = 0x{:?}\n", pyth.instance.contract_id().hash);
    println!("BTC price {:?}", pyth.price(btc_price_feed).await?.value);
    println!("ETH price {:?}", pyth.price(eth_price_feed).await?.value);
    println!("USDC price {:?}", pyth.price(usdc_price_feed).await?.value);

    Ok(())
}
