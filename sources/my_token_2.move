module contract_swap_sui::token2;
use sui::coin;
use sui::tx_context::{Self, TxContext};
use std::string::{Self, String};
use sui::object::{Self, UID};
use sui::transfer;

public struct Currency_Ranger has drop, key {}

fun init(witness: Currency_Ranger, ctx: &mut TxContext) {
    let (treasury, metadata) = coin::create_currency(
        witness,
        9,
        b"Currency Ranger",
        b"CRG",
        option::none(),
        ctx,
    );
    let coin = coin::mint(&treasury, 1000000000, ctx);
    transfer::public_transfer(coin, ctx.sender());

    transfer::public_freeze_object(metadata);
    transfer::public_transfer(treasury, ctx.sender());
}
// CAN SUA LAI GOP 2 FILE VOI NHAU VE TAO 2 TOKEN