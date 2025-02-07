/// SPDX-License-Identifier: GPL-3.0

module five_son::fee_rule {
    use sui::sui::SUI;
    use sui::coin::{Self, Coin};
    use sui::transfer_policy::{
        Self as policy,
        TransferPolicy,
        TransferPolicyCap,
        TransferRequest
    };

    const EIncorrectArgument: u64 = 0;
    const EInsufficientAmount: u64 = 1;

    const MAX_BPS: u16 = 10_000;

    struct Rule has drop {}

    struct VaultConfig has store, drop {
        fee_bp: u16,
        min_amount: u64
    }

    public fun set_fee<T: key + store>(policy: &mut TransferPolicy<T>, cap: &TransferPolicyCap<T>, fee_bp: u16, min_amount: u64) {
        assert!(fee_bp <= MAX_BPS, EIncorrectArgument);
        if (policy::has_rule<T, Rule>(policy)) {
            policy::remove_rule<T, Rule, VaultConfig>(policy, cap);
        };
        policy::add_rule(Rule {}, policy, cap, VaultConfig { fee_bp, min_amount })
    }

    public fun pay<T: key + store>(policy: &mut TransferPolicy<T>, request: &mut TransferRequest<T>, payment: Coin<SUI>) {
        let paid = policy::paid(request);
        let config: &VaultConfig = policy::get_rule(Rule {}, policy);
        let amount = (((paid as u128) * (config.fee_bp as u128) / 10_000) as u64);
        if (amount < config.min_amount) {
            amount = config.min_amount
        };
        assert!(coin::value(&payment) >= amount, EInsufficientAmount);
        policy::add_to_balance(Rule {}, policy, payment);
        policy::add_receipt(Rule {}, request)
    }
}