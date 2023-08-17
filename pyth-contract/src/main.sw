contract;

mod data_structures;
mod errors;
mod events;
mod interface;

use ::data_structures::{price::{Price, PriceFeed, PriceFeedId}};
use ::interface::{IPyth, PythGetters, PythSetters};

use std::{bytes::Bytes, u256::U256};

impl IPyth for Contract {
}
impl PythSetters for Contract {
}
impl PythGetters for Contract {
}
