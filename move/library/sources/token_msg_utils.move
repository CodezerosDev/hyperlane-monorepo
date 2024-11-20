module hp_library::token_msg_utils {

    use std::bcs;
    use std::vector;

    use aptos_std::from_bcs;

    use hp_library::utils::{ extract_from_bytes, extract_from_bytes_reversed };
    use hp_library::h256::{Self, H256};

    /// Convert message data into bytes
    ///
    public fun format_token_message_into_bytes(
        recipient: H256,
        amount: u256,
        metadata: vector<u8>,
    ): vector<u8> {
        let result = vector::empty<u8>();
        // convert into big-endian
        let amount_bytes = bcs::to_bytes<u256>(&amount);
        vector::reverse(&mut amount_bytes);

        vector::append(&mut result, h256::to_bytes(&recipient));
        vector::append(&mut result, amount_bytes);
        vector::append(&mut result, metadata);
        result
    }


    public fun recipient(bytes: &vector<u8>): address {
        from_bcs::to_address(extract_from_bytes(bytes, 0, 32))
    }

    public fun amount(bytes: &vector<u8>): u256 {
        from_bcs::to_u256(extract_from_bytes_reversed(bytes, 32, 64))
    }

    public fun token_id(bytes: &vector<u8>): u256 {
        amount(bytes)
    }

    public fun metadata(bytes: &vector<u8>): vector<u8> {
        extract_from_bytes(bytes, 39, 0)
    }
}



// 6-18
//
// ETH chain
// WETH 10.123456 (18)
// HY_C DESTINATION DECIMAL 10 10.12345678
// 10123456789a00000000
// 10123456789a00000000
//
// if (source < dest)
//     amount
//     data_amount = amount * (10 * abs(source-dest))
//
// else
//     amount
//     check (amount % 10 * abs(source-dest) == 0)
//     data_amount = amount / (10 * abs(source-dest))



// SUPRA chain
// WETH (8)
// HY DESTINATION DECIMAL
//
// SOURCE DECIMAL = 18
// TOKEN DECIMAL = 8
// 10200000000000000000
// 1020000000
//
//
// SUPRA chain -> ETH