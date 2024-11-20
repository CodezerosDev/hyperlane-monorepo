module tokens::hyper_coin_collateral {
    use std::vector;
    use std::signer;
    use aptos_std::table;
    use aptos_std::table::Table;
    use hp_router::router;
    use hp_library::msg_utils;
    use hp_library::h256;

    use hp_library::token_msg_utils;
    use hp_mailbox::mailbox;
    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::account::{Self, SignerCapability};
    use aptos_framework::aptos_coin::AptosCoin;

    // Constants

    const DEFAULT_GAS_AMOUNT: u256 = 1_000_000_000;

    const TOKEN_DEPOSIT_ACCOUNT_SEED: vector<u8> = b"supra_coin::SupraCoin";

    // Errors
    const ERROR_INVALID_DOMAIN: u64 = 0;

    struct HyperSupra {} // Actual coin type is going to be different from this

    struct State has key {
        cap: router::RouterCap<HyperSupra>,
        destination_decimals: Table<u32, u8>,
        received_messages: vector<vector<u8>>,
        signer_cap: SignerCapability,
    }


    /// Initialize Module
    fun init_module(account: &signer) {
        let cap = router::init<HyperSupra>(account);
        let (resource_signer, signer_cap) = account::create_resource_account(account, TOKEN_DEPOSIT_ACCOUNT_SEED);
        move_to<State>(&resource_signer, State {
            cap,
            destination_decimals: table::new(),
            received_messages: vector::empty(),
            signer_cap
        });
    }


    #[view]
    /// Calculates the power of a base raised to an exponent. The result ofbaseraised to the power ofexponent
    public fun calculate_power(base: u128, exponent: u16): u256 {
        let result: u256 = 1;
        let base: u256 = (base as u256);
        assert!((base | (exponent as u256)) != 0, 3);
        if (base == 0) { return 0 };
        while (exponent != 0)
            {
                if ((exponent & 0x1) == 1)
                    {
                        result = result * base;
                    };
                base = base * base;
                exponent = (exponent >> 1);
            };
        result
    }

    public entry fun set_destination_token_decimal(admin: &signer, dest_domain: u32, dest_decimal: u8) acquires State {
        assert!(signer::address_of(admin) == @tokens, 404);
        let state = borrow_global_mut<State>(@tokens);
        table::add(&mut state.destination_decimals, dest_domain, dest_decimal);
    }

    public entry fun transfer_remote(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires State {
        let state = borrow_global<State>(@tokens);
        assert!(table::contains(&state.destination_decimals, dest_domain), 2);
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupra>();
        let destination_decimals = *table::borrow(&state.destination_decimals, dest_domain);
        if (source_decimals < destination_decimals) {
            data_amount = (amount as u256) * calculate_power(10, ((destination_decimals - source_decimals) as u16));
        }
        else if (source_decimals < destination_decimals) {
            data_amount = (amount as u256);
        }
        else {
            data_amount = (amount as u256) / calculate_power(10, ((source_decimals - destination_decimals) as u16));
            amount = (data_amount as u64);
        };
        aptos_account::transfer_coins<AptosCoin>(
            account,
            generate_token_deposit_account_address(),
            amount
        );
        mailbox::dispatch<HyperSupra>(
            dest_domain,
            token_msg_utils::format_token_message_into_bytes(
                h256::from_bytes(&dest_receipient),
                data_amount,
                dest_receipient
            ),
            &state.cap
        );
    }

    public entry fun transfer_remote_with_gas(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires State {
        let state = borrow_global<State>(@tokens);
        assert!(table::contains(&state.destination_decimals, dest_domain), 2);
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupra>();
        let destination_decimals = *table::borrow(&state.destination_decimals, dest_domain);
        if (source_decimals < destination_decimals) {
            data_amount = (amount as u256) * calculate_power(10, ((destination_decimals - source_decimals) as u16));
        }
        else if (source_decimals < destination_decimals) {
            data_amount = (amount as u256);
        }
        else {
            data_amount = (amount as u256) / calculate_power(10, ((source_decimals - destination_decimals) as u16));
            amount = (data_amount as u64);
        };
        let sender = signer::address_of(account);
        aptos_account::transfer_coins<AptosCoin>(
            account,
            generate_token_deposit_account_address(),
            amount
        );
        mailbox::dispatch_with_gas<HyperSupra>(
            account,
            dest_domain,
            token_msg_utils::format_token_message_into_bytes(
                h256::from_bytes(&dest_receipient),
                data_amount,
                dest_receipient
            ),
            DEFAULT_GAS_AMOUNT,
            &state.cap
        );
    }


    /// Receive message from other chains
    public entry fun handle_message(
        message: vector<u8>,
        metadata: vector<u8>
    ) acquires State {
        let state = borrow_global_mut<State>(@tokens);

        mailbox::handle_message<HyperSupra>(
            message,
            metadata,
            &state.cap
        );

        let message_body = msg_utils::body(&message);

        let receipient_address = token_msg_utils::recipient(&message_body);
        let receipient_amount = token_msg_utils::amount(&message_body);

        aptos_account::transfer_coins<AptosCoin>(
            &account::create_signer_with_capability(&state.signer_cap),
            receipient_address,
            (receipient_amount as u64) // Here we need to take care of overflow underflow
        );
        vector::push_back(&mut state.received_messages, msg_utils::body(&message));
    }


    #[test]
    fun get_hello_world_bytes() {
        aptos_std::debug::print<vector<u8>>(&b"Hello World!");
        assert!(x"48656c6c6f20576f726c6421" == b"Hello World!", 0);
    }

    #[view]
    public fun generate_token_deposit_account_address(): address {
        account::create_resource_address(&@tokens, TOKEN_DEPOSIT_ACCOUNT_SEED)
    }
}
