/*
/// Module: contract_swap_sui
module contract_swap_sui::contract_swap_sui;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module contract_swap_sui::swap_token;
use sui::coin::{Self, Coin};
use sui::bag::{Self, Bag};
use sui::balance::{Self, Balance};
use  std::ascii::{Self, String};
use std::ascii::into_bytes;
use std::type_name::{get, into_string};
use sui::event;

const ERROR_NOT_POSITIVE_AMOUNT: u64 = 0;
const ERROR_POOL_NOT_EXIST: u64 = 1;
const ERROR_NOT_ENOUGH_BALANCE: u64 = 2;
const ERROR_NOT_SUITABLE_FEE: u64 = 3;

//pool store infor of pair (fromToken, toToken)
public struct Pool<phantom X, phantom Y> has key, store {
    id: UID,
    from_token: Balance<X>,
    to_token: Balance<Y>,
    numerator_of_rate: u64,
    denominator_of_rate: u64,
    fee: u64,
}

//for event
public struct SwapEvent has copy, drop {
    sender_address: address,
    from_token: String,
    to_token: String,
    amount_from: u64,
    amount_to: u64,
}

public struct AdminCap has key, store {
    id: UID,
}

fun init(ctx: &mut TxContext) {
    let admin = AdminCap {
        id: object::new(ctx),
    };
    // transfer::share_object(global);
    transfer::transfer(admin, tx_context::sender(ctx));
}

public entry fun create_pool<X,Y>(_admin: &AdminCap, numerator: u64, denominator: u64, fee: u64, ctx: &mut TxContext) {
    let pool = Pool<X, Y> {
        id: object::new(ctx),
        from_token: balance::zero<X>(),
        to_token: balance::zero<Y>(),  
        numerator_of_rate: numerator,
        denominator_of_rate: denominator,
        fee: fee,
    };
    transfer::share_object(pool);
}

public entry fun swap_token_x_to_y<X,Y>(amount: Coin<X>, pool: &mut Pool<X, Y>, ctx: &mut TxContext) {
    let from_token_amount = coin::value(&amount);

    let fee = pool.fee;
    //calculate amount of toToken received
    let amount_to = calculate_amount_to(pool, from_token_amount, fee, true);

    //check balance of toToken is enough
    assert!(balance::value(&pool.to_token) >= amount_to, ERROR_NOT_ENOUGH_BALANCE);

    //handle amount of fromToken 
    handle_amount_from_direct<X, Y>(pool, amount);

    //handle amount of toToken
    handle_amount_to_direct<X, Y>(pool, amount_to, ctx); 

    event::emit(SwapEvent {
        sender_address: tx_context::sender(ctx),
        from_token: into_string(get<X>()),
        to_token: into_string(get<Y>()),
        amount_from: from_token_amount,
        amount_to: amount_to,
    });
}
public entry fun swap_token_y_to_x<X,Y>(amount: Coin<Y>, pool: &mut Pool<X, Y>, ctx: &mut TxContext) {
    let from_token_amount = coin::value(&amount);

    let fee = pool.fee;
    //calculate amount of toToken received
    let amount_to = calculate_amount_to(pool, from_token_amount, fee, false);

    //check balance of toToken is enough
    assert!(balance::value(&pool.from_token) >= amount_to, ERROR_NOT_ENOUGH_BALANCE);

    //handle amount of fromToken 
    handle_amount_from_indirect<X, Y>(pool, amount);

    //handle amount of toToken
    handle_amount_to_indirect<X, Y>(pool, amount_to, ctx); 

    event::emit(SwapEvent {
        sender_address: tx_context::sender(ctx),
        from_token: into_string(get<X>()),
        to_token: into_string(get<Y>()),
        amount_from: from_token_amount,
        amount_to: amount_to,
    });
}

public entry fun withdraw<X,Y>(_admin: &AdminCap, pool: &mut Pool<X, Y>, amount_from: u64, amount_to: u64, ctx: &mut TxContext) {
    assert!(balance::value(&pool.from_token) >= amount_from, ERROR_NOT_ENOUGH_BALANCE);
    assert!(balance::value(&pool.to_token) >= amount_to, ERROR_NOT_ENOUGH_BALANCE);

    let amount_from_coin = coin::take<X>(&mut pool.from_token, amount_from, ctx);
    let amount_to_coin = coin::take<Y>(&mut pool.to_token, amount_to, ctx);
    transfer::public_transfer(amount_from_coin, tx_context::sender(ctx)); 
    transfer::public_transfer(amount_to_coin, tx_context::sender(ctx)); 
}

fun handle_amount_from_direct<X, Y>(pool: &mut Pool<X, Y>, from_token: Coin<X>) {
    let from_token_balance = coin::into_balance(from_token);
    balance::join(&mut pool.from_token, from_token_balance);
}

fun handle_amount_to_direct<X, Y>(pool: &mut Pool<X, Y>, amount: u64, ctx: &mut TxContext) {
    let amount_to_Coin = coin::take<Y>(&mut pool.to_token, amount, ctx);
    transfer::public_transfer(amount_to_Coin, tx_context::sender(ctx)); 
}

fun handle_amount_from_indirect<X, Y>(pool: &mut Pool<X, Y>, from_token: Coin<Y>) {
    let from_token_balance = coin::into_balance(from_token);
    balance::join(&mut pool.to_token, from_token_balance);
}

fun handle_amount_to_indirect<X, Y>(pool: &mut Pool<X, Y>, amount: u64, ctx: &mut TxContext) {
    let amount_to_Coin = coin::take<X>(&mut pool.from_token, amount, ctx);
    transfer::public_transfer(amount_to_Coin, tx_context::sender(ctx)); 
}

public entry fun reset_rate_pool<X,Y>(_admin: &AdminCap, pool: &mut Pool<X, Y>, numerator: u64, denominator: u64) {
    // check numerator and denominator is not equal to 0
    assert!(numerator > 0 && denominator > 0, ERROR_NOT_POSITIVE_AMOUNT);
    pool.numerator_of_rate = numerator;
    pool.denominator_of_rate = denominator;
}

public entry fun set_fee<X,Y>(_admin: &AdminCap, pool: &mut Pool<X, Y>, fee: u64) {
    // check fee is not over 1000
    assert!(fee > 0 && fee < 1000, ERROR_NOT_SUITABLE_FEE);
    pool.fee = fee;
}

public entry fun get_fee<X, Y>(pool: &Pool<X, Y>) : u64 {
    pool.fee
}

public entry fun get_rate_pool<X, Y>(pool: &Pool<X,Y>) : (u64, u64) {
    (pool.numerator_of_rate, pool.denominator_of_rate)
}

fun calculate_amount_to<X, Y>(pool: &Pool<X, Y>, amount: u64, fee: u64, is_direct: bool) : u64 {
    let amount_not_fee: u64;
    if (is_direct) {
        amount_not_fee = amount * pool.denominator_of_rate / pool.numerator_of_rate;
    } else {
        amount_not_fee = amount * pool.numerator_of_rate / pool.denominator_of_rate;
    };
    (amount_not_fee * (1000 - fee) / 1000)
}

public fun join_from_token<X, Y>(pool: &mut Pool<X, Y>, amount: Balance<X>) {
    balance::join(&mut pool.from_token, amount);
}

public fun join_to_token<X, Y>(pool: &mut Pool<X, Y>, amount: Balance<Y>) {
    balance::join(&mut pool.to_token, amount);
}

public fun get_from_token<X, Y>(pool: &mut Pool<X, Y>) : u64{
    balance::value<X>(&pool.from_token)
}

public fun get_to_token<X, Y>(pool: &mut Pool<X, Y>) : u64 {
    balance::value<Y>(&pool.to_token)
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}