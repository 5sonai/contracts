// SPDX-License-Identifier: GPL-3.0

module five_son::entries {
    use sui::tx_context::{Self, TxContext};
    use sui::transfer::{Self};
    use sui::coin::{Self};
    use sui::sui::SUI;
    use sui::clock::{Clock};

    use five_son::agent_nft::{Self, AGENT, VaultConfig, UserArchive, AdminCap};

    public entry fun mint(config: &mut VaultConfig, fund: coin::Coin<SUI>, sign: vector<u8>, msg: vector<u8>, archive: &mut UserArchive, clock: &Clock, ctx: &mut TxContext) {
        let nft = agent_nft::mint(config, fund, sign, msg, archive, clock, ctx);
        transfer::public_transfer(nft, tx_context::sender(ctx))
    }

    public entry fun burn(nft: AGENT, config: &VaultConfig, ctx: &mut TxContext) {
       agent_nft::burn(nft, config, ctx)
    }

    public entry fun withdraw_fee(admin_cap: &AdminCap, config: &mut VaultConfig, ctx: &mut TxContext) {
        let fee = agent_nft::withdraw_fee(admin_cap, config, ctx);
        transfer::public_transfer(fee, tx_context::sender(ctx))
    }

    public entry fun set_validator(admin: &AdminCap, config: &mut VaultConfig, validator_new: vector<u8>) {
        agent_nft::set_validator(admin, config, validator_new)
    }
}