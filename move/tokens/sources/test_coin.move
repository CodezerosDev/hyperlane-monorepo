module tokens::fusion_coin {
    use std::signer;
    use std::string;
    use std::error;
    use aptos_framework::aptos_account;
    use aptos_framework::coin;

    const ENOT_OWNER: u64 = 0;
    const E_ALREADY_HAS_CAPABILITY: u64 = 1;
    const E_DONT_HAVE_CAPABILITY: u64 = 2;

    struct FusionCoin {}

    struct FusionCapability has key {
        burn_cap: coin::BurnCapability<FusionCoin>,
        freeze_cap: coin::FreezeCapability<FusionCoin>,
        mint_cap: coin::MintCapability<FusionCoin>,
    }

    fun only_owner(addr: address) {
        assert!(addr == @tokens, ENOT_OWNER);
    }


    fun init_module(account: &signer) {
        let (burn_cap, freeze_cap, mint_cap) = coin::initialize<FusionCoin>(
            account,
            string::utf8(b"FUSION"),
            string::utf8(b"FUSION"),
            6,
            true,
        );
        coin::register<FusionCoin>(account);
        let coins = coin::mint(10000000000000000, &mint_cap);
        coin::deposit(signer::address_of(account), coins);


        move_to(account, FusionCapability {
            burn_cap,
            freeze_cap,
            mint_cap,
        });
    }

    ///Can only be called by `tokens`.
    public entry fun mint_by_owner(user: &signer, account: address, amount: u64) acquires FusionCapability {
        assert!(signer::address_of(user) == @tokens, error::permission_denied(ENOT_OWNER));
        let caps = borrow_global<FusionCapability>(@tokens);
        let coins = coin::mint(amount, &caps.mint_cap);
        aptos_account::deposit_coins<FusionCoin>(account, coins);
    }
}