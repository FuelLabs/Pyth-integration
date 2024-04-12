library;

pub struct WormholeProvider {
    pub governance_chain_id: u16,
    pub governance_contract: b256,
}

impl WormholeProvider {
    pub fn new(governance_chain_id: u16, governance_contract: b256) -> Self {
        WormholeProvider {
            governance_chain_id,
            governance_contract,
        }
    }
}
