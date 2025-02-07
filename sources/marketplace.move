/// SPDX-License-Identifier: GPL-3.0

module five_son::marketplace {
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::kiosk::{Self, Kiosk, KioskOwnerCap};
    use sui::coin::{Coin};
    use sui::sui::{SUI};
    use sui::object::{Self, ID};
    use sui::package::{Publisher, claim};
    use sui::transfer_policy::{Self, TransferRequest, TransferPolicy};

    use five_son::agent_nft::{AGENT};

    struct MARKETPLACE has drop {}

    fun init(otw: MARKETPLACE, ctx: &mut TxContext) {
        let publisher = claim(otw, ctx);
        transfer::public_transfer(publisher, tx_context::sender(ctx));

        let (kiosk, kiosk_owner_cap) = kiosk::new(ctx);
        transfer::public_share_object(kiosk);
        transfer::public_transfer(kiosk_owner_cap, tx_context::sender(ctx));
    }

    #[allow(lint(self_transfer, share_owned))]
    public fun create_policy(publisher: &Publisher, ctx: &mut TxContext) {
        let (policy, policy_cap) = transfer_policy::new<AGENT>(publisher, ctx);
        transfer::public_share_object(policy);
        transfer::public_transfer(policy_cap, tx_context::sender(ctx));
    }

    public fun place_and_list(kiosk: &mut Kiosk, cap: &KioskOwnerCap, item: AGENT, price: u64) {
        let item_id = object::id<AGENT>(&item);
        kiosk::place<AGENT>(kiosk, cap, item);
        kiosk::list<AGENT>(kiosk, cap, item_id, price)
    }

    public fun remove(kiosk: &mut Kiosk, cap: &KioskOwnerCap, item_id: ID): AGENT {
        kiosk::take(kiosk, cap, item_id)
    }

    public fun update_price(kiosk: &mut Kiosk, cap: &KioskOwnerCap, item_id: ID, new_price: u64) {
        kiosk::delist<AGENT>(kiosk, cap, item_id);
        kiosk::list<AGENT>(kiosk, cap, item_id, new_price)
    }

    public fun buy(kiosk: &mut Kiosk, item_id: ID, payment: Coin<SUI>): (AGENT, TransferRequest<AGENT>){
        kiosk::purchase<AGENT>(kiosk, item_id, payment)
    }

    public fun confirm_request(policy: &TransferPolicy<AGENT>, req: TransferRequest<AGENT>) {
        transfer_policy::confirm_request(policy, req);
    }
}
