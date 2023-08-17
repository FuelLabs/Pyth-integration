contract;

mod data_structures;
mod errors;
mod events;
mod interface;

use ::data_structures::{price::{Price, PriceFeedId}};
use ::interface::Pyth;

impl Pyth for Contract {
}
