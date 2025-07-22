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


//TODO: NOTICE TO OWNERSHIP OF ASSET

const ERROR_NOT_POSITIVE_AMOUNT: u64 = 0;

//create Global variable to store pools (pair of fromToken and toToken)
public struct Global has key {
    id: UID,
    pools: Bag,
}

//pool store infor of pair (fromToken, toToken)
public struct Pool<phantom X, phantom Y> has key {
    id: UID,
    from_token: Balance<X>,
    to_token: Balance<Y>,
    numerator_of_rate: u64,
    denominator_of_rate: u64,
}

fun init(ctx: &mut TxContext) {
    let global = Global {
        id: object::new(ctx),
        pools: bag::new(ctx), 
    };
    transfer::share_object(global);
}

fun add_pool<X,Y>(global: &mut Global, numerator: u64, denominator: u64, ctx: &mut TxContext) {   
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

    bag::add(&mut global.pools, pool_name_XY, pool);
    bag::add(&mut global.pools, pool_name_YX, pool);
}

//create key(name) for bag
fun create_pool_name<X, Y>() : String {
    let name = string::utf8(b""); // TODO: use mut and no mut difference ???
    string::append_utf8(&mut name, into_bytes(into_string(get<X>())));
    string::append_utf8(&mut name, b"_");
    string::append_utf8(&mut name, into_bytes(into_string(get<Y>())));
    name
}

//TODO: NOTICE check exist of pool
fun get_pool<X, Y>(global: &mut Global) : &mut Pool<X, Y> {
    let pool_name = create_pool_name<X, Y>();
    bag::borow<String, Pool<X, Y>>(&mut global.pools, pool_name);
}

fun swap_token<X,Y>(global: &mut Global, amount: Coin<X>, ctx: &mut TxContext) {
    let from_token_amount = coin::value(&amount);
    // check amount > 0
    assert!(from_token_amount > 0, ERROR_NOT_POSITIVE_AMOUNT);
    //check pool exist
    let pool_name = create_pool_name<X, Y>(); // TODO : notice ownership of asset
    assert!(bag::contains_with_type<String, Pool<X,Y>>(&global.pools, pool_name), 1);

    let pool = get_pool<X, Y>(global);
    handle_amount_from<X, Y>(global, amount, ctx);
    let amount_to = calculate_amount_to(pool, from_token_amount);
    handle_amount_to<X, Y>(global, amount_to, ctx);

    
}
//TODO:notice ownership of asset
fun handle_amount_from<X, Y>(global: &mut Global, from_token: Coin<X>, ctx: &mut TxContext) {
    let from_token_balance = coin::into_balance(from_token);
    balance::join(&mut get_pool<X, Y>(global).from_token, from_token_balance);
}
fun handle_amount_to<X, Y>(global: &mut Global, amount: u64, ctx: &mut TxContext) {
    let amount_to_Coin = coin::take<X>(&mut global.to_token, amount, ctx); //TODO: notive mut of asset
    transfer::transfer(amount_to_Coin, tx_context::sender(ctx)); // transfer to sender
}
fun calculate_amount_to<X, Y>(pool: &mut Pool<X, Y>, amount: u64) : u64 {
    let amount_not_fee = amount * pool.numerator_of_rate / pool.denominator_of_rate;
    amount_not_fee * (1000 - pool.fee) / 1000 // TODO: notice fee
}
