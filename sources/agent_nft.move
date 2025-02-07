/// SPDX-License-Identifier: GPL-3.0

module five_son::agent_nft {
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::package::{Self};
    use sui::display::{Self};
    use sui::transfer::{Self};
    use sui::event::{Self};
    use std::string::{Self};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::table::{Self, Table};
    use std::option::{Self, Option};
    use sui::sui::{SUI};
    use sui::clock::{Self, Clock};
    use sui::ed25519;
    use sui::bcs;

    const VERSION: u64 = 1;

    const EInsufficientFund: u64 = 1000;
    const EWrongVersion: u64 = 1002;
    const ENotUpgrade: u64 = 1003;
    const EValidatorEmpty: u64 = 1004;
    const EBadSign: u64 = 1005;
    const EPermission: u64 = 1006;
    const ESignExp: u64 = 1007;
    const EBadNonce: u64 = 1008;

    struct AGENT_NFT has drop {
    }

    struct AdminCap has key, store {
        id: UID
    }

    struct VaultConfig has store, key {
        id: UID,
        version: u64,
        validator: Option<vector<u8>>,
        minting_fee: Balance<SUI>
    }

    struct AGENT has store, key {
        id: UID,
        xid: string::String,
        name: string::String,
        description: string::String
    }

    struct UserArchive has key, store {
        id: UID,
        user_nonce: Table<address, u128>,
    }

    struct MintedEvent has copy, drop {
        user: address,
        id: ID,
        xid: string::String,
        name: string::String,
        description: string::String,
    }

    struct BurnedEvent has copy, drop {
        user: address,
        id: ID,
        xid: string::String,
        name: string::String,
        description: string::String,
    }
    
    fun init(otw: AGENT_NFT, ctx: &mut TxContext) {
        let owner = tx_context::sender(ctx);

        let fields = vector[
            string::utf8(b"name"),
            string::utf8(b"description"),
            string::utf8(b"image_url"),
            string::utf8(b"link"),
            string::utf8(b"project_url"),
            string::utf8(b"creator"),
        ];

        let values = vector[
            string::utf8(b"{name}"),
            string::utf8(b"{description}"),
            string::utf8(b"https://storage.local/assets/{xid}/.png"),
            string::utf8(b"https://storage.local/detail/{xid}"),
            string::utf8(b"https://x.com/5son"),
            string::utf8(b"5SON"),
        ];

        let publisher = package::claim(otw, ctx);
        let display = display::new_with_fields<AGENT>(&publisher, fields, values, ctx);
        display::update_version<AGENT>(&mut display);

        transfer::public_transfer(display, owner);
        transfer::public_transfer(publisher, owner);

        transfer::public_transfer(AdminCap { id: object::new(ctx)}, owner);

        transfer::public_share_object(UserArchive { id: object::new(ctx), user_nonce: table::new(ctx) });

        transfer::public_share_object(VaultConfig {
            id: object::new(ctx),
            version: VERSION,
            minting_fee: balance::zero<SUI>(),
            validator: option::none()
        })
    }

    public fun mint(config: &mut VaultConfig, fund: coin::Coin<SUI>, sign: vector<u8>, msg: vector<u8>, archive: &mut UserArchive, clock: &Clock, ctx: &mut TxContext): AGENT {
        assert!(config.version == VERSION, EWrongVersion);

        verifySignature(sign, msg, &config.validator);

        let receipent = tx_context::sender(ctx);

        let timestamp = clock::timestamp_ms(clock);
        let bcs = bcs::new(msg);
        let (receiver, xid, name, description, mint_fee, expire_timestamp, nonce) = (
            bcs::peel_address(&mut bcs),
            bcs::peel_vec_u8(&mut bcs),
            bcs::peel_vec_u8(&mut bcs),
            bcs::peel_vec_u8(&mut bcs),
            bcs::peel_u64(&mut bcs),
            bcs::peel_u64(&mut bcs),
            bcs::peel_u128(&mut bcs)
        );

        assert!(receipent == receiver, EPermission);
        assert!(expire_timestamp > timestamp, ESignExp);
        let current_nonce = if(table::contains(&archive.user_nonce, receiver)) {
            table::borrow_mut(&mut archive.user_nonce, receiver)
        } else {
            table::add(&mut archive.user_nonce, receiver, 0);
            table::borrow_mut(&mut archive.user_nonce, receiver)
        };
        assert!(*current_nonce < nonce, EBadNonce);
        *current_nonce = *current_nonce + 1;

        assert!(coin::value(&fund) == mint_fee, EInsufficientFund);

        balance::join(&mut config.minting_fee, coin::into_balance<SUI>(fund));

        let nft = AGENT {
            id: object::new(ctx),
            xid: string::utf8(xid),
            name: string::utf8(name),
            description:  string::utf8(description),
        };

        let event = MintedEvent{
            user: tx_context::sender(ctx),
            id: object::id(&nft),
            xid: nft.xid,
            name: nft.name,
            description: nft.description,
        };
        event::emit<MintedEvent>(event);

        nft
    }

    public fun burn(nft: AGENT, config: &VaultConfig, ctx: &mut TxContext) {
        assert!(config.version == VERSION, EWrongVersion);
        let AGENT {
            id: uid,
            xid: xid,
            name: name,
            description: description
        } = nft;
        let event = BurnedEvent{
            user: tx_context::sender(ctx), 
            id: object::uid_to_inner(&uid), 
            xid,
            name,
            description,
        };
        event::emit<BurnedEvent>(event);

        object::delete(uid);
    }

    public fun withdraw_fee(_admin_cap: &AdminCap, config: &mut VaultConfig, ctx: &mut TxContext): Coin<SUI> {
        assert!(config.version == VERSION, EWrongVersion);
        let fee_amount = balance::value(&config.minting_fee);
        coin::take(&mut config.minting_fee, fee_amount, ctx)
    }

    public fun set_validator(_admin: &AdminCap, config: &mut VaultConfig, validator_new: vector<u8>) {
        assert!(config.version == VERSION, EWrongVersion);
        option::swap_or_fill(&mut config.validator, validator_new);
    }

    public fun migrate(_admin_cap: &AdminCap, config: &mut VaultConfig) {
        assert!(config.version < VERSION, ENotUpgrade);
        config.version = VERSION;
    }

    fun verifySignature(sign: vector<u8>, msg: vector<u8>, validator: &Option<vector<u8>>) {
        assert!(option::is_some<vector<u8>>(validator), EValidatorEmpty);
        assert!(ed25519::ed25519_verify(&sign, option::borrow(validator), &msg), EBadSign);
    }
}

