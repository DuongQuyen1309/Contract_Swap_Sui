module contract_swap_sui::token;
use sui::coin::{Self, TreasuryCap};
use sui::tx_context::{Self, TxContext};
use std::string::{Self, String};
use sui::object::{Self, UID};
use sui::transfer;
use sui::coin::create_currency;
use std::option;

const ERROR_NOT_POSITIVE_AMOUNT: u64 = 0;
const ERROR_NOT_OWNER: u64 = 1;

public struct AdminCap has key {
    id: UID,
}
public struct Token has drop, key {}

fun init(ctx: &mut TxContext) {
    let admin = AdminCap {
        id: object::new(ctx),
    };
    transfer::transfer(admin, ctx.sender());
}

fun create_token<X>(admin: &AdminCap, witness: X, decimals: u8, symbol: vector<u8>, name: vector<u8>, description: vector<u8>, ctx: &mut TxContext) : (TreasuryCap<X>) {
    assert!(ctx.sender() == object::owner(admin), ERROR_NOT_OWNER);
    let (treasuryCap, metadata) = coin::create_currency(
        X, 
        decimals, 
        symbol, 
        name, 
        description, 
        option::none(), 
        ctx,
    );
    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasuryCap, ctx.sender());
    (treasuryCap);
}

public entry fun mint_token<X>(admin: &AdminCap, treasury: &mut TreasuryCap<X>,value: u64, ctx: &mut TxContext) {
    assert!(ctx.sender() == object::owner(admin), ERROR_NOT_OWNER);
    assert!(value > 0, ERROR_NOT_POSITIVE_AMOUNT);
    let coin = coin::mint(treasury, value, ctx);
    transfer::public_transfer(coin, ctx.sender());
}
// CAN SUA LAI GOP 2 FILE VOI NHAU VE TAO 2 TOKEN
// CAN PHAI TAI LAI SUI SO FILE CLIENT.YAML MẤT TIÊU RỒI