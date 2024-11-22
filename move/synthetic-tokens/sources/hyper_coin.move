module synthetic_tokens::hyper_coin {
    use std::vector;
    use std::string;
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

    // Constants

    const DEFAULT_GAS_AMOUNT: u256 = 1_000_000_000;

    // Errors
    const ERROR_INVALID_DOMAIN: u64 = 0;

    struct HyperSupraCoin {} //Need to be the coin type

    struct State has key {
        cap: router::RouterCap<HyperSupraCoin>,
        destination_decimals: Table<u32, u8>,
        received_messages: vector<vector<u8>>,
        last_id: vector<u8>
    }

    struct CoinCapability has key {
        burn_cap: coin::BurnCapability<HyperSupraCoin>,
        freeze_cap: coin::FreezeCapability<HyperSupraCoin>,
        mint_cap: coin::MintCapability<HyperSupraCoin>,
    }

    /// Initialize Module
    fun init_module(account: &signer) {
        let cap = router::init<HyperSupraCoin>(account);
        move_to<State>(account, State {
            cap,
            destination_decimals: table::new(),
            received_messages: vector::empty(),
            last_id: vector::empty()
        });

        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<HyperSupraCoin>(
            account,
            string::utf8(b"HyperSupraCoin"),
            string::utf8(b"HyperCoin"),
            6,
            true,
        );
        coin::register<HyperSupraCoin>(account);

        move_to(account, CoinCapability {
            burn_cap,
            freeze_cap,
            mint_cap,
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
        assert!(signer::address_of(admin) == @synthetic_tokens, 404);
        let state = borrow_global_mut<State>(@synthetic_tokens);
        table::add(&mut state.destination_decimals, dest_domain, dest_decimal);
    }

    public entry fun transfer_remote(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires CoinCapability, State {
        let state = borrow_global_mut<State>(@synthetic_tokens);
        assert!(table::contains(&state.destination_decimals, dest_domain), 2);
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupraCoin>();
        //assert for destination decimals for graceful exit
        let destination_decimals = *table::borrow(&state.destination_decimals, dest_domain);
        if (source_decimals < destination_decimals) {
            data_amount = (amount as u256) * calculate_power(10, ((destination_decimals - source_decimals) as u16));
        }
        else if (source_decimals == destination_decimals) {
            data_amount = (amount as u256);
        }
        else {
            data_amount = (amount as u256) / calculate_power(10, ((source_decimals - destination_decimals) as u16));
            amount = (data_amount as u64);
        };
        let sender = signer::address_of(account);
        let caps = borrow_global<CoinCapability>(@synthetic_tokens);
        coin::burn_from<HyperSupraCoin>(sender, amount, &caps.burn_cap);
        state.last_id = mailbox::dispatch<HyperSupraCoin>(
            dest_domain,
            token_msg_utils::format_token_message_into_bytes(
                h256::from_bytes(&dest_receipient),
                data_amount,
                dest_receipient
            ),
            &state.cap
        );
        // add an event
    }

    public entry fun transfer_remote_with_gas(
        account: &signer,
        dest_domain: u32,
        dest_receipient: vector<u8>,
        amount: u64) acquires CoinCapability, State {
        let state = borrow_global_mut<State>(@synthetic_tokens);
        assert!(table::contains(&state.destination_decimals, dest_domain), 2);
        let data_amount: u256;
        let source_decimals = coin::decimals<HyperSupraCoin>();
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
        let caps = borrow_global<CoinCapability>(@synthetic_tokens);
        coin::burn_from(sender, amount, &caps.burn_cap);
        state.last_id = mailbox::dispatch_with_gas<HyperSupraCoin>(
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
        // add an event
    }


    /// Receive message from other chains
    public entry fun handle_message(
        message: vector<u8>,
        metadata: vector<u8>
    ) acquires State, CoinCapability {
        let state = borrow_global_mut<State>(@synthetic_tokens);

        mailbox::handle_message<HyperSupraCoin>(
            message,
            metadata,
            &state.cap
        );

        let src_domain = msg_utils::origin_domain(&message);

        let message_body = msg_utils::body(&message);

        let receipient_address = token_msg_utils::recipient(&message_body);
        let receipient_amount = token_msg_utils::amount(&message_body);


        let destination_decimals = coin::decimals<HyperSupraCoin>();
        let source_decimals = *table::borrow(&state.destination_decimals, src_domain);

        let amount;

        if (source_decimals < destination_decimals) {
            amount = (receipient_amount * calculate_power(
                10,
                ((destination_decimals - source_decimals) as u16)
            ) as u64);
        }
        else if (source_decimals == destination_decimals) {
            amount = (receipient_amount as u64);
        }
        else {
            amount = ((receipient_amount / calculate_power(
                10,
                ((source_decimals - destination_decimals) as u16)
            )) as u64);
        };


        let caps = borrow_global<CoinCapability>(@synthetic_tokens);
        let coins = coin::mint<HyperSupraCoin>(
            amount,
            &caps.mint_cap
        ); // Here we need to take care of overflow underflow
        aptos_account::deposit_coins<HyperSupraCoin>(receipient_address, coins);
        // add an event
    }

    #[view]
    public fun view_last_id(): vector<u8> acquires State {
        let state = borrow_global<State>(@synthetic_tokens);
        state.last_id
    }


    #[test]
    fun get_hello_world_bytes() {
        aptos_std::debug::print<vector<u8>>(&b"Hello World!");
        assert!(x"48656c6c6f20576f726c6421" == b"Hello World!", 0);
    }
}
