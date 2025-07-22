module contract_swap_sui::token;
use sui::coin;
use sui::tx_context::{Self, TxContext};
use std::string::{Self, String};
use sui::object::{Self, UID};
use sui::transfer;

public struct Token has drop, key {}

fun init(witness: Token, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        9,
        b"Power Range",
        b"PRG",
        option::none(),
        ctx,
    );
    let coin = coin::mint(&treasury, 1000000000, ctx);
    transfer::public_transfer(coin, ctx.sender());

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
}



// CAN SUA LAI GOP 2 FILE VOI NHAU VE TAO 2 TOKEN
// CAN PHAI TAI LAI SUI SO FILE CLIENT.YAML MẤT TIÊU RỒI