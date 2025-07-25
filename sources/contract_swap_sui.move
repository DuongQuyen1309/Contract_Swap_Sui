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
use std::string::{Self, String};
use std::ascii::into_bytes;
use std::type_name::{get, into_string};
use sui::event;



//assert!(ctx.sender() == object::owner(admin), E_NOT_OWNER); nên thêm vào nhwunxg trường nhạy cảm


//TODO: NOTICE TO OWNERSHIP OF ASSET
const ERROR_NOT_POSITIVE_AMOUNT: u64 = 0;
const ERROR_POOL_NOT_EXIST: u64 = 1;
const ERROR_NOT_ENOUGH_BALANCE: u64 = 2;
const ERROR_NOT_SUITABLE_FEE: u64 = 3;

//create Global variable to store pools (pair of fromToken and toToken)
public struct Global has key {
    id: UID,
    pools: Bag,
    fee: u64,
}

//pool store infor of pair (fromToken, toToken)
public struct Pool<phantom X, phantom Y> has key, store {
    id: UID,
    from_token: Balance<X>,
    to_token: Balance<Y>,
    numerator_of_rate: u64,
    denominator_of_rate: u64,
}

public struct SwapEvent has copy, drop {
    sender_address: address,
    from_token: std::ascii::String,
    to_token: std::ascii::String,
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
    let global = Global {
        id: object::new(ctx),
        pools: bag::new(ctx), 
        fee: 1, //0.1%
    };
    transfer::share_object(global);
    transfer::transfer(admin, tx_context::sender(ctx));
}

public fun compare_token_name(a: std::ascii::String, b: std::ascii::String): bool {
    let a_bytes = into_bytes(a);
    let b_bytes = into_bytes(b);
    let a_len = vector::length(&a_bytes);
    let b_len = vector::length(&b_bytes);
    let mut min_len = 0;
    if (a_len < b_len) { min_len = a_len };
    if (a_len >= b_len) { min_len = b_len };

    let mut i = 0;
    let mut result = false;
    while (i < min_len) {
        let a_byte = *vector::borrow(&a_bytes, i);
        let b_byte = *vector::borrow(&b_bytes, i);
        if (a_byte < b_byte) {
            result = true;
            break
        };
        if (a_byte > b_byte) {
            result = false;
            break
        };
        i = i + 1;
    };
    if (i == min_len) {
        result = a_len < b_len;
    };
    result 
}

public fun create_pool_name<X, Y>() : String { 
    let mut name = string::utf8(b"");
    string::append_utf8(&mut name, into_bytes(into_string(get<X>())));
    string::append_utf8(&mut name, b"_");
    string::append_utf8(&mut name, into_bytes(into_string(get<Y>())));
    move(name)
}

public entry fun add_pool<X,Y>(_admin: &AdminCap, global: &mut Global, numerator: u64, denominator: u64, ctx: &mut TxContext) {   
    assert!(numerator > 0 && denominator > 0, ERROR_NOT_POSITIVE_AMOUNT);
    create_pool<X,Y>(global, numerator, denominator, ctx);
    create_pool<Y,X>(global, denominator, numerator, ctx);
}

fun create_pool<X,Y>(global: &mut Global, numerator: u64, denominator: u64, ctx: &mut TxContext) {
    let pool_name = create_pool_name<X, Y>();
    assert!(!bag::contains_with_type<String, Pool<X,Y>>(&global.pools, pool_name), ERROR_POOL_NOT_EXIST);
    let pool = Pool<X, Y> {
        id: object::new(ctx),
        from_token: balance::zero<X>(),
        to_token: balance::zero<Y>(),  
        numerator_of_rate: numerator,
        denominator_of_rate: denominator,
    };
    bag::add(&mut global.pools, pool_name, pool);
}

public fun get_pool<X, Y>(global: &mut Global) : &mut Pool<X, Y> {
    let pool_name = create_pool_name<X, Y>();
    assert!(bag::contains_with_type<String, Pool<X,Y>>(&global.pools, pool_name), ERROR_POOL_NOT_EXIST);
    bag::borrow_mut<String, Pool<X, Y>>(&mut global.pools, pool_name)
}

public entry fun swap_token<X,Y>(global: &mut Global, amount: Coin<X>, ctx: &mut TxContext) {
    let from_token_amount = coin::value(&amount);

    // check amount > 0
    assert!(from_token_amount > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let fee = global.fee;

    //calculate amount of toToken received
    let amount_to = calculate_amount_to(get_pool<X, Y>(global), from_token_amount, fee);

    let pool = get_pool<X, Y>(global);
    //check balance of toToken is enough
    assert!(balance::value(&pool.to_token) >= amount_to, ERROR_NOT_ENOUGH_BALANCE);

    //handle amount of fromToken 
    handle_amount_from<X, Y>(global, amount);

    //handle amount of toToken
    handle_amount_to<X, Y>(global, amount_to, ctx); 

    event::emit(SwapEvent {
        sender_address: tx_context::sender(ctx),
        from_token: into_string(get<X>()),
        to_token: into_string(get<Y>()),
        amount_from: from_token_amount,
        amount_to: amount_to,
    });
}

fun handle_amount_from<X, Y>(global: &mut Global, from_token: Coin<X>) {
    let from_token_balance = coin::into_balance(from_token);
    balance::join(&mut get_pool<X, Y>(global).from_token, from_token_balance);
}

fun handle_amount_to<X, Y>(global: &mut Global, amount: u64, ctx: &mut TxContext) {
    let amount_to_Coin = coin::take<Y>(&mut get_pool<X, Y>(global).to_token, amount, ctx);
    transfer::public_transfer(amount_to_Coin, tx_context::sender(ctx)); 
}

public entry fun reset_rate_pool<X,Y>(_admin: &AdminCap, global: &mut Global, numerator: u64, denominator: u64) {
    // check numerator and denominator are positive
    assert!(numerator > 0 && denominator > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let pool = get_pool<X, Y>(global);
    pool.numerator_of_rate = numerator;
    pool.denominator_of_rate = denominator;
}

public entry fun set_fee(_admin: &AdminCap, global: &mut Global, fee: u64) {
    // check fee is positive
    assert!(fee > 0 && fee < 1000, ERROR_NOT_SUITABLE_FEE);
    global.fee = fee;
}

fun calculate_amount_to<X, Y>(pool: &Pool<X, Y>, amount: u64, fee: u64) : u64 {
    let amount_not_fee = amount * pool.denominator_of_rate / pool.numerator_of_rate;
    amount_not_fee * (1000 - fee) / 1000
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