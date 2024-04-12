library;

use ::errors::WormholeError;
use std::{
    array_conversions::b256::*,
    b512::B512,
    bytes::Bytes,
    vm::evm::ecr::ec_recover_evm_address,
};
pub struct GuardianSignature {
    pub guardian_index: u8,
    pub r: b256,
    pub s: b256,
    pub v: u8,
}
impl GuardianSignature {
    pub fn new(guardian_index: u8, r: b256, s: b256, v: u8) -> Self {
        GuardianSignature {
            guardian_index,
            r,
            s,
            v,
        }
    }
    // eip-2098: Compact Signature Representation
    pub fn compact(self) -> B512 {
        let y_parity = b256::from_be_bytes([
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            0u8,
            self.v - 27u8,
        ]);
        let shifted_y_parity = y_parity.lsh(255);
        let y_parity_and_s = b256::binary_or(shifted_y_parity, self.s);
        B512::from((self.r, y_parity_and_s))
    }
    pub fn verify(
        self,
        guardian_set_key: b256,
        hash: b256,
        index: u64,
        last_index: u64,
) {
        // Ensure that provided signature indices are ascending only
        if index > 0 {
            require(
                self.guardian_index
                    .as_u64() > last_index,
                WormholeError::SignatureIndicesNotAscending,
            );
        }
        let recovered_signer = ec_recover_evm_address(self.compact(), hash);
        require(
            recovered_signer
                .is_ok() && recovered_signer
                .unwrap()
                .bits() == guardian_set_key,
            WormholeError::SignatureInvalid,
        );
    }
}
