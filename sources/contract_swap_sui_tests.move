
#[test_only]
module contract_swap_sui::swap_token_test{
    use sui::test_scenario;
    use sui::test_utils;
    use sui::accumulator;
    use contract_swap_sui::crg;
    use contract_swap_sui::prg;
    use contract_swap_sui::crg::{CRG};
    use contract_swap_sui::prg::{PRG};
    use contract_swap_sui::swap_token;
    use contract_swap_sui::swap_token::{AdminCap as SwapAdmin, Global}; 
    use sui::coin;
    use sui::package;
    use sui::balance;


    const ERROR_NOT_EQUAL_BALANCE_IN_POOL: u64 = 999;
    const ERROR_NOT_EQUAL_RATE_IN_POOL: u64 = 999;

    //NEED TO TEST CASE BAD

    // case1: swap 1000 prg -> 1980 crg with rate 1:2 and fee = 1%
    #[test]
    fun test_swap_prg_crg_case1() {
        set_up_test_swap<PRG, CRG>(1, 2, 1000, 51000, 48020);
    }

    // case2: swap 1000 prg -> 6930 crg with rate 2:7 and fee = 1%
    #[test]
    fun test_swap_prg_crg_case2() {
        set_up_test_swap<PRG, CRG>(2, 7, 2000, 52000, 43070);
    }

    // case3: swap 1000 crg -> 3960 crg with rate 3: 4 and fee = 1%
    #[test]
    fun test_swap_crg_prg() {
        set_up_test_swap<CRG, PRG>(3, 4, 3000, 53000, 46040);
    }

    #[test]
    fun test_set_fee() {
        set_up_set_fee(30, 30);
    }


    #[test_only]
    fun set_up_test_swap<X, Y>(numerator: u64, denominator: u64, amount: u64, expect_x: u64, expect_y: u64) {
        let owner = @0xA;
        let mut scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;
        
        //create token CRG to test
        test_scenario::next_tx(scenario, owner);
        crg::init_for_testing(test_scenario::ctx(scenario));

        //create token PRG to test
        test_scenario::next_tx(scenario, owner);
        prg::init_for_testing(test_scenario::ctx(scenario));

        //initialize swap_token contract
        test_scenario::next_tx(scenario, owner);
        swap_token::init_for_testing(test_scenario::ctx(scenario));

        //take admin authorization and global of contract_swap_sui
        test_scenario::next_tx(scenario, owner);
        let admin = test_scenario::take_from_sender<SwapAdmin>(scenario);
        let mut global = test_scenario::take_shared<Global>(scenario);  

        test_scenario::next_tx(scenario, owner);
        swap_token::add_pool<X, Y>(
            &admin, 
            &mut global, 
            numerator,
            denominator, 
            test_scenario::ctx(scenario),
        );
        test_scenario::next_tx(scenario, owner);

        test_scenario::next_tx(scenario, owner);
        let mut coin_x = test_scenario::take_from_sender<coin::Coin<X>>(scenario); 
        let mut coin_y = test_scenario::take_from_sender<coin::Coin<Y>>(scenario);          

        //get coin to transfer to pool
        let coin_x_to_pool = coin::split(&mut coin_x, 50000, test_scenario::ctx(scenario));
        let coin_y_to_pool = coin::split(&mut coin_y, 50000, test_scenario::ctx(scenario));

        //transform from coin -> balance
        let balance_x_to_pool = coin::into_balance(coin_x_to_pool);
        let balance_y_to_pool = coin::into_balance(coin_y_to_pool);
        {
            //get pool to deposit into pool
            let mut pool = swap_token::get_pool<X, Y>(&mut global);

            //deposit into pool
            swap_token::join_from_token<X, Y>(pool, balance_x_to_pool); //NOTICE: ownership of pool
            swap_token::join_to_token<X, Y>(pool, balance_y_to_pool);
        };
        
        // get crg coin to deposit swap contract 
        let coin_x_to_swap = coin::split(&mut coin_x, amount, test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, owner);
        swap_token::swap_token<X,Y>(&mut global,coin_x_to_swap,test_scenario::ctx(scenario));
        {
            let mut pool = swap_token::get_pool<X, Y>(&mut global);
            let x_balance = swap_token::get_from_token<X, Y>(pool);
            let y_balance = swap_token::get_to_token<X, Y>(pool);
            assert!(x_balance == expect_x,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
            assert!(y_balance == expect_y,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        };
        //return coin to owner
        test_scenario::next_tx(scenario, owner);
        transfer::public_transfer(coin_x, tx_context::sender(test_scenario::ctx(scenario)));
        transfer::public_transfer(coin_y, tx_context::sender(test_scenario::ctx(scenario)));
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(global);
        test_scenario::end(scenario_val);
    }

    #[test_only]
    fun set_up_set_fee(fee: u64, expected_fee: u64) {
        let owner = @0xA;
        let mut scenario_val = test_scenario::begin(owner);
        let scenario = &mut scenario_val;

         //initialize swap_token contract
        test_scenario::next_tx(scenario, owner);
        swap_token::init_for_testing(test_scenario::ctx(scenario));

        test_scenario::next_tx(scenario, owner);
        let admin = test_scenario::take_from_sender<SwapAdmin>(scenario);
        let mut global = test_scenario::take_shared<Global>(scenario);

        test_scenario::next_tx(scenario, owner);
        swap_token::set_fee(&admin, &mut global, fee);
        assert!(swap_token::get_fee(&mut global) == expected_fee, ERROR_NOT_EQUAL_RATE_IN_POOL);

        test_scenario::next_tx(scenario, owner);
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(global);
        test_scenario::end(scenario_val);
    }
}