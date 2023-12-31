library;

use std::{bytes::Bytes, hash::{Hash, keccak256}};
use ::errors::PythError;

/// Concatenated to leaf input as described by
/// "MTH({d(0)}) = KECCAK-256(0x00 || d(0))"
pub const LEAF = 0u8;
/// Concatenated to node input as described by
/// "MTH(D[n]) = KECCAK-256(0x01 || MTH(D[0:k]) || MTH(D[k:n]))"
pub const NODE = 1u8;

fn leaf_digest(data: Bytes) -> Bytes {
    let mut bytes = Bytes::new();
    bytes.push(LEAF);
    bytes.append(data);

    let (slice, _) = Bytes::from(keccak256(bytes)).split_at(20);

    slice
}

fn node_digest(left: Bytes, right: Bytes) -> Bytes {
    let mut bytes = Bytes::with_capacity(41);
    bytes.push(NODE);

    let l: b256 = left.into();
    let r: b256 = right.into();
    if l < r {
        bytes.append(left);
        bytes.append(right);
    } else {
        bytes.append(right);
        bytes.append(left);
    }

    let (slice, _) = Bytes::from(keccak256(bytes)).split_at(20);

    slice
}

pub fn validate_proof(
    encoded_proof: Bytes,
    leaf_data: Bytes,
    ref mut proof_offset: u64,
    root: Bytes,
) -> u64 {
    let mut current_digest = leaf_digest(leaf_data);

    let proof_size = encoded_proof.get(proof_offset).unwrap().as_u64();
    proof_offset += 1;

    let mut i = 0;
    while i < proof_size {
        let (_, slice) = encoded_proof.split_at(proof_offset);
        let (sibling_digest, _) = slice.split_at(20);
        proof_offset += 20;

        current_digest = node_digest(current_digest, sibling_digest);

        i += 1;
    }

    require(current_digest == root, PythError::InvalidProof);

    proof_offset
}
