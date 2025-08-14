
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
    use contract_swap_sui::swap_token::{Pool};
    use contract_swap_sui::swap_token::{AdminCap as SwapAdmin};
    use sui::coin::{TreasuryCap}; 
    use contract_swap_sui::crg::{AdminCap as AdminCrg};
    use contract_swap_sui::prg::{AdminCap as AdminPrg};
    use sui::coin;
    use sui::package;
    use sui::balance;

    const ERROR_NOT_EQUAL_BALANCE_IN_POOL: u64 = 999;
    const ERROR_NOT_EQUAL_FEE_IN_POOL: u64 = 888;
    const ERROR_NOT_EQUAL_RATE_IN_POOL: u64 = 777;

    // case1: success : swap 1000 prg -> 1980 crg with rate 1:2 and fee = 1% (10/1000)
    #[test]
    fun test_swap_prg_crg_case1() {
        set_up_test_swap<PRG, CRG>(1, 2, 10, 1000, 51000, 48020, true);
    }

    // case2: success : swap 3000 crg -> 990 prg with rate 3:1 and fee = 1%. swap crg with prg but inverse to pool <prg,crg>
    #[test]
    fun test_swap_prg_crg_case2() {
        // set_up_test_swap<PRG, CRG>(2, 7, 10, 2000, 52000, 43070, true);
        set_up_test_swap<PRG, CRG>(1, 3, 10, 3000, 49010, 53000, false);
    }

    // case3: success : swap 1000 crg -> 3960 crg with rate 3: 4 and fee = 1%
    #[test]
    fun test_swap_crg_prg() {
        set_up_test_swap<CRG, PRG>(3, 4, 10, 3000, 53000, 46040, true);
    }

    //case 4: success : set fee with 30 (equal 3%)
    #[test]
    fun test_set_fee() {
        set_up_set_fee<CRG, PRG>(30, 30);
    }

    //case 5: success : set rate of pool(CRG, PRG) and (PRG, CRG) with 3:4 and 4:3
    #[test]
    fun test_set_rate(){
        set_up_reset_rate<CRG, PRG>(3, 4, 3, 4);
    }

    //case 6: success : create pool(CRG, PRG) and (PRG, CRG) with 3:4 and 4:3 and fee = 10
    #[test]
    fun test_create_pool(){
        set_up_create_pool<CRG, PRG>(3, 4, 10, 3, 4, 10);
    }

    //case 7: success : withdraw 1000 crg and 500 prg from pool(PRG, CRG)
    #[test]
    fun test_withdraw(){
        set_up_withdraw<CRG, PRG>(1000, 500, 49000, 49500);
    }

    //case 8: success : deposit 50000 crg and 50000 prg in pool
    #[test]
    fun test_deposit(){
        set_up_deposit<CRG, PRG>(50000, 50000, 50000, 50000);
    }

    //case 9: fail : amount that swap is over balance of pools
    #[test]
    #[expected_failure]
    fun test_swap_over_amount(){
        set_up_test_swap<PRG, CRG>(1, 2,10,  50000, 51000, 48020, true);
    }

    //case 10: fail : rate = 0 
    #[test]
    #[expected_failure]
    fun test_set_rate_equal_0(){
        set_up_reset_rate<CRG, PRG>(0, 5, 0, 5);
    }

    //case 11: fail : fee > 1000 
    #[test]
    #[expected_failure]
    fun test_set_fee_over_1000(){
        set_up_set_fee<CRG, PRG>(1010, 1010);
    }

    #[test_only]
    fun set_up_scenario(): (address, test_scenario::Scenario) {
        let owner = @0xA;
        let scenario_val = test_scenario::begin(owner);
        (owner, scenario_val)
    }

    #[test_only]
    fun set_up_test_swap<X, Y>(numerator: u64, denominator: u64, fee: u64, amount: u64, expect_x: u64, expect_y: u64, is_direct: bool) {
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        min_token(1000000, 1000000,&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(numerator, denominator,fee,&mut scenario, owner);

        test_scenario::next_tx(&mut scenario, owner);
        let mut coin_x = test_scenario::take_from_sender<coin::Coin<X>>(&mut scenario); 
        let mut coin_y = test_scenario::take_from_sender<coin::Coin<Y>>(&mut scenario);          

        //get coin to transfer to pool
        let coin_x_to_pool = coin::split(&mut coin_x, 50000, test_scenario::ctx(&mut scenario));
        let coin_y_to_pool = coin::split(&mut coin_y, 50000, test_scenario::ctx(&mut scenario));

        //transform from coin -> balance
        let balance_x_to_pool = coin::into_balance(coin_x_to_pool);
        let balance_y_to_pool = coin::into_balance(coin_y_to_pool);
        //get pool to deposit into pool
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);

        //deposit into pool
        swap_token::join_from_token<X, Y>(&mut pool, balance_x_to_pool); 
        swap_token::join_to_token<X, Y>(&mut pool, balance_y_to_pool);
        
        // get x coin to deposit swap contract 
        // let coin_x_to_swap = coin::split(&mut coin_x, amount, test_scenario::ctx(scenario));

        // test_scenario::next_tx(scenario, owner);
        // swap_token::swap_token<X,Y>(coin_x_to_swap, &mut pool, test_scenario::ctx(scenario));
        swap_token<X,Y>(is_direct, amount, &mut pool, &mut coin_x, &mut coin_y, owner,&mut scenario);

        let x_balance = swap_token::get_from_token<X, Y>(&mut pool);
        let y_balance = swap_token::get_to_token<X, Y>(&mut pool);
        assert!(x_balance == expect_x,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        assert!(y_balance == expect_y,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        //return coin to owner
        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(coin_x, tx_context::sender(test_scenario::ctx(&mut scenario)));
        transfer::public_transfer(coin_y, tx_context::sender(test_scenario::ctx(&mut scenario)));
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(pool);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun swap_token<X,Y>(is_direct: bool, amount: u64, pool: &mut Pool<X,Y>, coin_x: &mut coin::Coin<X>, coin_y: &mut coin::Coin<Y>, owner: address, scenario: &mut test_scenario::Scenario){
        test_scenario::next_tx(scenario, owner);
        if (is_direct) {
            let coin_x_to_swap = coin::split(coin_x, amount, test_scenario::ctx(scenario));
            swap_token::swap_token_x_to_y<X,Y>(coin_x_to_swap, pool, test_scenario::ctx(scenario));
            return
        };

        let coin_y_to_swap = coin::split(coin_y, amount, test_scenario::ctx(scenario));
        swap_token::swap_token_y_to_x<X,Y>(coin_y_to_swap, pool, test_scenario::ctx(scenario));
    }

    #[test_only]
    fun set_up_create_pool<X,Y>(numerator: u64, denominator: u64, fee: u64, expected_num: u64, expected_deno: u64, expected_fee :u64){
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(numerator, denominator, fee, &mut scenario, owner);

        test_scenario::next_tx(&mut scenario, owner);
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);
        
        test_scenario::next_tx(&mut scenario, owner);
        let (num, deno) = swap_token::get_rate_pool<X,Y>(&pool);
        assert!(num == expected_num, ERROR_NOT_EQUAL_RATE_IN_POOL);
        assert!(deno == expected_deno, ERROR_NOT_EQUAL_RATE_IN_POOL);
        assert!(swap_token::get_fee(&mut pool) == expected_fee, ERROR_NOT_EQUAL_FEE_IN_POOL);
        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(pool);
        test_scenario::end(scenario);
    }
    
    #[test_only]
    fun set_up_set_fee<X, Y>(fee: u64, expected_fee: u64) {
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(1, 3, 10, &mut scenario, owner); // fee = 10 approx 10/1000
        
        test_scenario::next_tx(&mut scenario, owner);
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        swap_token::set_fee(&admin, &mut pool, fee);
        assert!(swap_token::get_fee(&mut pool) == expected_fee, ERROR_NOT_EQUAL_FEE_IN_POOL);

        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(pool);
        // test_scenario::end(scenario_val);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun set_up_reset_rate<X,Y>(new_num: u64, new_deno: u64, expected_num: u64, expected_deno: u64) {
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(1, 3, 10, &mut scenario, owner);  // fee = 10 approx 10/1000
        test_scenario::next_tx(&mut scenario, owner);
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        swap_token::reset_rate_pool<X,Y>(&admin, &mut pool, new_num, new_deno);
        let (num, deno) = swap_token::get_rate_pool<X,Y>(&pool);
        assert!(num == expected_num, ERROR_NOT_EQUAL_RATE_IN_POOL);
        assert!(deno == expected_deno, ERROR_NOT_EQUAL_RATE_IN_POOL);
        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(admin, owner);
        test_scenario::return_shared(pool);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun set_up_withdraw<X,Y>(amount_from: u64, amount_to: u64, expected_from_balance_of_pool: u64, expected_to_balance_of_pool: u64) {
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        min_token(1000000, 1000000,&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(1, 3, 10,&mut scenario, owner);

        test_scenario::next_tx(&mut scenario, owner);
        let mut coin_x = test_scenario::take_from_sender<coin::Coin<X>>(&mut scenario); 
        let mut coin_y = test_scenario::take_from_sender<coin::Coin<Y>>(&mut scenario);        

        //get coin to transfer to pool
        let coin_x_to_pool = coin::split(&mut coin_x, 50000, test_scenario::ctx(&mut scenario));
        let coin_y_to_pool = coin::split(&mut coin_y, 50000, test_scenario::ctx(&mut scenario));

        //transform from coin -> balance
        let balance_x_to_pool = coin::into_balance(coin_x_to_pool);
        let balance_y_to_pool = coin::into_balance(coin_y_to_pool);
        //get pool to deposit into pool
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);

        //deposit into pool
        swap_token::join_from_token<X, Y>(&mut pool, balance_x_to_pool); 
        swap_token::join_to_token<X, Y>(&mut pool, balance_y_to_pool);

        test_scenario::next_tx(&mut scenario, owner);
        swap_token::withdraw<X,Y>(&admin, &mut pool, amount_from, amount_to, test_scenario::ctx(&mut scenario));
        let x_balance = swap_token::get_from_token<X, Y>(&mut pool);
        let y_balance = swap_token::get_to_token<X, Y>(&mut pool);
        assert!(x_balance == expected_from_balance_of_pool,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        assert!(y_balance == expected_to_balance_of_pool,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(admin, owner);
        transfer::public_transfer(coin_x, tx_context::sender(test_scenario::ctx(&mut scenario)));
        transfer::public_transfer(coin_y, tx_context::sender(test_scenario::ctx(&mut scenario)));
        test_scenario::return_shared(pool);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun set_up_deposit<X,Y>(amount_from: u64, amount_to: u64, expected_from_balance_of_pool: u64, expected_to_balance_of_pool: u64) {
        let (owner, mut scenario) = set_up_scenario();
        intialize_contract_swap_contract_token(&mut scenario, owner);
        min_token(1000000, 1000000,&mut scenario, owner);
        let admin : SwapAdmin = set_up_admin_treasury_pool<X,Y>(1, 3, 10,&mut scenario, owner);
        
        test_scenario::next_tx(&mut scenario, owner);
        let mut pool = test_scenario::take_shared<Pool<X,Y>>(&mut scenario);

        test_scenario::next_tx(&mut scenario, owner);
        let mut coin_x = test_scenario::take_from_sender<coin::Coin<X>>(&mut scenario); 
        let mut coin_y = test_scenario::take_from_sender<coin::Coin<Y>>(&mut scenario);        

        test_scenario::next_tx(&mut scenario, owner);
        swap_token::deposit<X,Y>(&admin, &mut pool, coin_x, coin_y, amount_from, amount_to, test_scenario::ctx(&mut scenario));
        let x_balance = swap_token::get_from_token<X, Y>(&mut pool);
        let y_balance = swap_token::get_to_token<X, Y>(&mut pool);
        assert!(x_balance == expected_from_balance_of_pool,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        assert!(y_balance == expected_to_balance_of_pool,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        test_scenario::next_tx(&mut scenario, owner);
        transfer::public_transfer(admin, owner);
        // transfer::public_transfer(coin_x, tx_context::sender(test_scenario::ctx(&mut scenario)));
        // transfer::public_transfer(coin_y, tx_context::sender(test_scenario::ctx(&mut scenario)));
        test_scenario::return_shared(pool);
        test_scenario::end(scenario);
    }

    #[test_only]
    fun intialize_contract_swap_contract_token(scenario: &mut test_scenario::Scenario, owner: address){
        //initialize swap_token contract
        test_scenario::next_tx(scenario, owner);
        swap_token::init_for_testing(test_scenario::ctx(scenario));

        //create token CRG to test
        test_scenario::next_tx(scenario, owner);
        crg::init_for_testing(test_scenario::ctx(scenario));

        //create token PRG to test
        test_scenario::next_tx(scenario, owner);
        prg::init_for_testing(test_scenario::ctx(scenario));

    }

    #[test_only]
    fun set_up_admin_treasury_pool<X,Y>(numerator: u64, denominator: u64, fee: u64, scenario: &mut test_scenario::Scenario, owner: address) : (SwapAdmin) {
        test_scenario::next_tx(scenario, owner);
        let admin = test_scenario::take_from_sender<SwapAdmin>(scenario); 
        test_scenario::next_tx(scenario, owner);
        swap_token::create_pool<X, Y>(
            &admin, 
            numerator,
            denominator, 
            fee,
            test_scenario::ctx(scenario),
        );
        admin
    }

    #[test_only]
    fun min_token(coin_of_crg: u64, coin_of_prg: u64, scenario: &mut test_scenario::Scenario, owner: address){
        test_scenario::next_tx(scenario, owner);
        let mut treasury_crg = test_scenario::take_from_sender<TreasuryCap<CRG>>(scenario);  
        let mut treasury_prg = test_scenario::take_from_sender<TreasuryCap<PRG>>(scenario); 
        let admin_crg = test_scenario::take_from_sender<AdminCrg>(scenario);
        let admin_prg = test_scenario::take_from_sender<AdminPrg>(scenario);
        test_scenario::next_tx(scenario, owner);
        prg::mint(&admin_prg, &mut treasury_prg, coin_of_prg, owner,test_scenario::ctx(scenario));
        crg::mint(&admin_crg, &mut treasury_crg, coin_of_crg, owner,test_scenario::ctx(scenario));
        transfer::public_transfer(treasury_crg, owner);
        transfer::public_transfer(treasury_prg, owner);
        transfer::public_transfer(admin_crg, owner);
        transfer::public_transfer(admin_prg, owner);
    }
}