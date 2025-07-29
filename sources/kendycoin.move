/*
/// Module: kendycoin
module kendycoin::kendycoin;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module kendycoin::kendy {
    use std::ascii::string;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::url;

    public struct KENDY has drop {}

    fun init(otw: KENDY, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency<KENDY>(
        otw,
        0,                                              // decimals
        b"KENDY",                                       // symbol
        b"Kendycoin",                                   // name
        b"Kendy's own coin! Wow!",                      // description
        option::some(url::new_unsafe(string(b"https://aggregator.walrus-testnet.walrus.space/v1/blobs/PSLo-YV_qOlw1x-qRJuAGpwBclbRKfTs_7AChdCI83g"))), // icon_url
        ctx
        );

        transfer::public_freeze_object(metadata);
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
    }

    public entry fun mint_kendy(cap: &mut TreasuryCap<KENDY>, value: u64, ctx: &mut TxContext) {
        let kendy = coin::mint(cap, value, ctx);
        transfer::public_transfer(kendy, tx_context::sender(ctx));
    }

    #[error]
    const ETooMuch: vector<u8> = b"Tried burning too much of a coin object.";

    public entry fun burn_kendy_V2(cap: &mut TreasuryCap<KENDY>, c: &mut Coin<KENDY>, amount: u64, ctx: &mut TxContext): u64 {
        let value = coin::value(c);
        assert!(value >= amount, ETooMuch);
        let burnt = coin::split(c, amount, ctx);
        coin::burn(cap, burnt)
    }

    public entry fun burn_kendy(cap: &mut TreasuryCap<KENDY>, kendy: Coin<KENDY>, amount: u64, ctx: &mut TxContext): u64 {
        let mut c = kendy;
        let value = coin::value(&c);
        assert!(value >= amount, ETooMuch);
        if (value == amount) { coin::burn(cap, c) } else {
            let burnt = coin::split(&mut c, amount, ctx);

            transfer::public_transfer(c, tx_context::sender(ctx));
            coin::burn(cap, burnt)
        }
    }
}

module kendycoin::coffee_machine {
    use sui::balance::{Self, Balance,};  //For handling sui token balances
    use sui::coin::{Self, Coin};
    use kendycoin::kendy::KENDY;

    /// Coffee machine is a shared object, hence requires `key` ability.
    public struct CoffeeMachine has key { id: UID, counter: u16, balance: Balance<KENDY> }

    /// Cup is an owned object.
    public struct Cup has key, store { id: UID, has_coffee: bool }

    public struct WithdrawCap has key { id: UID }

    /// Initialize the module and share the `CoffeeMachine` object.
    fun init(ctx: &mut TxContext) {
        transfer::transfer(WithdrawCap<> { id: object::new(ctx) }, tx_context::sender(ctx));
        transfer::share_object(CoffeeMachine {
            id: object::new(ctx),
            counter: 0,
            balance: balance::zero()
        });
    }

    // Enable withdrawals for others
    public entry fun grant_withdraw_cap(_: &WithdrawCap, recipient: address, ctx: &mut TxContext) {
        let withdraw_cap = WithdrawCap {id: object::new(ctx)};
        transfer::transfer(withdraw_cap, recipient);
    }

    /// Take a cup out of thin air. This is a fast path operation.
    public entry fun take_cup(ctx: &mut TxContext) {
        transfer::transfer(Cup { id: object::new(ctx), has_coffee: false }, tx_context::sender(ctx))
    }

    /// Make coffee and pour it into the cup. Requires consensus.
    public entry fun make_coffee(machine: &mut CoffeeMachine, cup: &mut Cup, payment: &mut Coin<KENDY>, amount: u64) {
        machine.counter = machine.counter + 1;
        cup.has_coffee = true;

        // Handle payment
        let coin_balance = coin::balance_mut(payment);
        let paid = balance::split(coin_balance, amount);
        balance::join(&mut machine.balance, paid);
    }

    /// Drink coffee from the cup. This is a fast path operation.
    public entry fun drink_coffee(cup: &mut Cup) {
        cup.has_coffee = false;
    }

    /// Put the cup back. This is a fast path operation.
    public entry fun put_back(cup: Cup) {
        let Cup { id, has_coffee: _ } = cup;
        id.delete();
    }

    public entry fun withdraw_balance(
        _: &WithdrawCap,
        machine: &mut CoffeeMachine,     // Mutable reference to the NFT we're withdrawing from 
        amount: u64,              // Amount to withdraw (in MIST)
        ctx: &mut TxContext       // Transaction context for creating new coin
    ) {
        // Split specified amount from NFT's balance and create new coin
        let withdrawn = coin::from_balance(
            balance::split(&mut machine.balance, amount), 
            ctx
        );
        
        // Transfer the new coin to the transaction sender
        transfer::public_transfer(withdrawn, tx_context::sender(ctx));
    }
}
