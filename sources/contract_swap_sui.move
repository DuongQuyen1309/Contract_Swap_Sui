/*
/// Module: contract_swap_sui
module contract_swap_sui::contract_swap_sui;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module contract_swap_sui::swap_token;
use sui::object::{Self, UID};
use sui::balance::{Self, Balance};
use sui::tx_context::{Self, TxContext};
use sui::transfer;
use sui::coin::{Self, Coin};
use contract_swap_sui::token::Token;
use sui::bag::{Self, Bag};
use sui::bag::add;
use std::string::{Self, String};
use std::ascii::into_bytes;
use std::type_name::{get, into_string};
use std::string::append_utf8;
use sui::transfer::share_object;
use sui::event;
use std::address;


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
public struct Pool<phantom X, phantom Y> has key {
    id: UID,
    from_token: Balance<X>,
    to_token: Balance<Y>,
    numerator_of_rate: u64,
    denominator_of_rate: u64,
}

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
    let global = Global {
        id: object::new(ctx),
        pools: bag::new(ctx), 
        fee: 1, //0.1%
    };
    transfer::share_object(global); // TODO: authorize again
    transfer::transfer(admin, tx_context::sender(ctx));
}

fun add_pool<X,Y>(admin: &AdminCap, global: &mut Global, numerator: u64, denominator: u64, ctx: &mut TxContext) {   
    // check numerator and denominator are positive
    assert!(numerator > 0 && denominator > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let pool_name_XY = create_pool_name<X, Y>();
    let pool_name_YX = create_pool_name<Y, X>();

    let pool_XY = Pool<X, Y> {
        id: object::new(),
        from_token: balance::zero<X>(), // TODO: can mint amount
        to_token: balance::zero<Y>(),   // TODO: can mint amount
        numerator_of_rate: numerator,
        denominator_of_rate: denominator,
    };

    let pool_YX = Pool<Y, X> {
        id: object::new(),
        from_token: balance::zero<Y>(), // TODO: can mint amount
        to_token: balance::zero<X>(),   // TODO: can mint amount
        numerator_of_rate: denominator,
        denominator_of_rate: numerator,
    };

    bag::add(&mut global.pools, pool_name_XY, pool_XY);
    bag::add(&mut global.pools, pool_name_YX, pool_YX);
}

fun reset_rate_pool<X,Y>(admin: &AdminCap, global: &mut Global, numerator: u64, denominator: u64, ctx: &mut TxContext) {
    // check numerator and denominator are positive
    assert!(numerator > 0 && denominator > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let pool_name = create_pool_name<X, Y>();
    let pool = get_pool<X, Y>(global);
    pool.numerator_of_rate = numerator;
    pool.denominator_of_rate = denominator;
}

fun set_fee(admin: &AdminCap, global: &mut Global, fee: u64) {
    // check fee is positive
    assert!(fee > 0 && fee < 1000, ERROR_NOT_SUITABLE_FEE);
    global.fee = fee;
}

//create key(name) for bag
fun create_pool_name<X, Y>() : String {
    let name = string::utf8(b""); // TODO: use mut and no mut difference ???
    string::append_utf8(&mut name, into_bytes(into_string(get<X>())));
    string::append_utf8(&mut name, b"_");
    string::append_utf8(&mut name, into_bytes(into_string(get<Y>())));
    name
}

fun get_pool<X, Y>(global: &mut Global) : &mut Pool<X, Y> {
    let pool_name = create_pool_name<X, Y>();
    assert!(bag::contains_with_type<String, Pool<X,Y>>(&global.pools, pool_name), ERROR_POOL_NOT_EXIST);
    bag::borow_mut<String, Pool<X, Y>>(&mut global.pools, pool_name);
}

fun swap_token<X,Y>(global: &mut Global, amount: Coin<X>, ctx: &mut TxContext) {
    let from_token_amount = coin::value(&amount);

    // check amount > 0
    assert!(from_token_amount > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let pool_name = create_pool_name<X, Y>();
    let pool = get_pool<X, Y>(global);
    let fee = global.fee;

    //calculate amount of toToken received
    let amount_to = calculate_amount_to(&pool, from_token_amount, fee);

    //check balance of toToken is enough
    assert!(balance::value(&pool.to_token) >= amount_to, ERROR_NOT_ENOUGH_BALANCE);

    //handle amount of fromToken 
    handle_amount_from<X, Y>(&mut global, amount, ctx);

    //handle amount of toToken
    handle_amount_to<X, Y>(&mut global, amount_to, ctx); 

    event::emit(SwapEvent {
        sender_address: tx_context::sender(ctx),
        from_token: into_string(get<X>()),
        to_token: into_string(get<Y>()),
        amount_from: from_token_amount,
        amount_to: amount_to,
    });
}

fun handle_amount_from<X, Y>(global: &mut Global, from_token: Coin<X>, ctx: &mut TxContext) {
    let from_token_balance = coin::into_balance(from_token);
    balance::join(&mut get_pool<X, Y>(global).from_token, from_token_balance);
}

fun handle_amount_to<X, Y>(global: &mut Global, amount: u64, ctx: &mut TxContext) {
    let amount_to_Coin = coin::take<X>(&mut get_pool<X, Y>(global).to_token, amount, ctx);
    transfer::transfer(amount_to_Coin, tx_context::sender(ctx)); 
}

fun calculate_amount_to<X, Y>(pool: &Pool<X, Y>, amount: u64, fee: u64) : u64 {
    let amount_not_fee = amount * pool.numerator_of_rate / pool.denominator_of_rate;
    amount_not_fee * (1000 - fee) / 1000 
}

#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
    init(ctx);
}