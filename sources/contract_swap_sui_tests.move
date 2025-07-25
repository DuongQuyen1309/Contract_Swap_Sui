
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
    // use contract_swap_sui::token::AdminCap as TokenAdmin;
    use sui::coin;
    use sui::package;
    use sui::balance;
    /*    
        // Bắt đầu môi trường test (test scenario)
        let mut scenario = test_scenario::begin();

        // Tạo các tài khoản test
        let owner = test_scenario::create_account(&mut scenario);
        let user1 = test_scenario::create_account(&mut scenario);
        let user2 = test_scenario::create_account(&mut scenario);

        // Các hành động tiếp theo: publish package, call swap, kiểm tra...
    */

    const ERROR_NOT_EQUAL_BALANCE_IN_POOL: u64 = 999;
    #[test]
    fun test_swap_token() {
        let owner = @0xA;
        // let user1 = @0xB;
        // let user2 = @0xC;

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
        swap_token::add_pool<PRG, CRG>(
            &admin, 
            &mut global, 
            1,
            2, 
            test_scenario::ctx(scenario),
        );

        test_scenario::next_tx(scenario, owner);
            let mut coin_prg = test_scenario::take_from_sender<coin::Coin<PRG>>(scenario);
            let mut coin_crg = test_scenario::take_from_sender<coin::Coin<CRG>>(scenario);          

            let coin_prg_to_pool = coin::split(&mut coin_prg, 50000, test_scenario::ctx(scenario));
            let coin_crg_to_pool = coin::split(&mut coin_crg, 50000, test_scenario::ctx(scenario));
            
            let balance_prg_to_pool = coin::into_balance(coin_prg_to_pool);
            let balance_crg_to_pool = coin::into_balance(coin_crg_to_pool);

            let mut pool = swap_token::get_pool<PRG, CRG>(&mut global); //global had mut

            swap_token::join_from_token<PRG, CRG>(pool, balance_prg_to_pool); //NOTICE: ownership of pool
            swap_token::join_to_token<PRG, CRG>(pool, balance_crg_to_pool);
            
            /*
                let prg_balance = swap_token::get_from_token<PRG, CRG>(pool);
                let crg_balance = swap_token::get_to_token<PRG, CRG>(pool);

                assert!(prg_balance == 50000,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
                assert!(crg_balance == 50000,ERROR_NOT_EQUAL_BALANCE_IN_POOL);
            */
            
            transfer::public_transfer(coin_crg, tx_context::sender(test_scenario::ctx(scenario)));
            transfer::public_transfer(coin_prg, tx_context::sender(test_scenario::ctx(scenario)));
            transfer::public_transfer(admin, owner);
            test_scenario::return_shared(global);
        /*
            test_scenario::next_tx(scenario, owner);
            let coin = test_scenario::take_from_sender<coin::Coin<CRG>>(scenario);
            let balance = coin::into_balance(coin);
            let value = balance::value(&balance);
            assert(value == 1000000, ERROR_NOT_EQUAL_BALANCE_IN_POOL);
            let coin_back = coin::from_balance(balance, test_scenario::ctx(scenario));
            transfer::public_transfer(coin_back, tx_context::sender(test_scenario::ctx(scenario)));

            let coin = test_scenario::take_from_sender<coin::Coin<PRG>>(scenario);
            let balance = coin::into_balance(coin);
            let value = balance::value(&balance);
            assert(value == 1000000, ERROR_NOT_EQUAL_BALANCE_IN_POOL);
            let coin_back = coin::from_balance(balance, test_scenario::ctx(scenario));
            transfer::public_transfer(coin_back, tx_context::sender(test_scenario::ctx(scenario)));
        */
        
        /*
            test_scenario::next_tx(scenario, owner);
            swap_token::init_for_testing(test_scenario::ctx(scenario));
            
            test_scenario::next_tx(scenario, owner);
            let admin = test_scenario::take_from_sender<SwapAdmin>(scenario);
            let mut global = test_scenario::take_shared<Global>(scenario);

            test_scenario::next_tx(scenario, owner);
            {
                swap_token::add_pool<PRG, CRG>(
                    &admin, 
                    &mut global, 
                    1,
                    2, 
                    test_scenario::ctx(scenario),
                );
            };
            test_scenario::next_tx(scenario, owner);
            let mut coin_of_PRG = test_scenario::take_from_sender<Coin<PRG>>(scenario);
            let mut coin_of_CRG = test_scenario::take_from_sender<Coin<CRG>>(scenario);

            //notice: remain of coin can return to owner ??????
            let coin_PRG_sent_to_pool = coin::split(&mut coin_of_PRG, 1000, test_scenario::ctx(scenario));
            let coin_CRG_sent_to_pool = coin::split(&mut coin_of_CRG, 1000, test_scenario::ctx(scenario));

            let balance_PRG_sent_to_pool = coin::into_balance(coin_PRG_sent_to_pool);
            let balance_CRG_sent_to_pool = coin::into_balance(coin_CRG_sent_to_pool);
            let pool = swap_token::get_pool<PRG, CRG>(&mut global);
            swap_token::join_from_token<PRG, CRG>(pool, balance_PRG_sent_to_pool);
            swap_token::join_to_token<PRG, CRG>(pool, balance_CRG_sent_to_pool);
            
            transfer::public_transfer(coin_of_PRG, owner);
            transfer::public_transfer(coin_of_CRG, owner);

            let prg_balance = swap_token::get_from_token<PRG, CRG>(pool);
            let _crg_balance = swap_token::get_to_token<PRG, CRG>(pool);
            test_scenario::return_shared(global);
            transfer::public_transfer(admin_token, owner);
            transfer::public_transfer(admin_token2, owner);
            transfer::public_transfer(admin, owner);
            assert!(prg_balance == 1000, ERROR_NOT_EQUAL_BALANCE_IN_POOL);
        */
        test_scenario::end(scenario_val);
    }

}