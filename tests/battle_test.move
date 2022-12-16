#[test_only]
module suimon::battle_tests {
    use sui::test_scenario;
    use sui::tx_context;
    use sui::transfer;
    use suimon::battle::{Self, Battle};
    use suimon::suimon::{Self, Suimon};
    
    #[test]
    fun test_create() {
        let (coach_a, coach_b, referree) = coaches();
        let ctx = tx_context::dummy();
        let battle = battle::create(coach_a, coach_b, 3, &mut ctx);


        transfer::transfer(battle, referree);
    }

    #[test]
    fun test_is_participant() {
        let (coach_a, coach_b, other) = coaches();
        let suimon_per_coach = 3;

        let ctx = tx_context::dummy();
        let battle = battle::create(coach_a, coach_b, suimon_per_coach, &mut ctx);
        let should_be_true = battle::is_participant(&battle, coach_a);
        let should_be_false = battle::is_participant(&battle, other);

        assert!(should_be_true == true, 0);
        assert!(should_be_false == false, 1);

        // transfer somewhere so that the move engine won't dump on us.
        transfer::transfer(battle, other);
    }

    // #[test]
    // fun test_suimon_count_for_coach() {
    //     let (coach_a, coach_b, other) = coaches();
    //     let ctx = tx_context::dummy();
    //     let battle =  battle::create(coach_a, coach_b, 3, &mut ctx);

    //     // transfer somewhere so that the move engine won't dump on us.
    //     transfer::transfer(battle, other);
    // }

    #[test]
    fun test_initiate_battle() {
        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 3;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, suimon_per_coach, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            // assert!(battle.state == 0, 0);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_accept_battle() {
        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 3;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, suimon_per_coach, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            battle::accept_battle(&mut battle, test_scenario::ctx(scenario));
            // assert!(battle.state == 1, 0);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_decline_battle() {
        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 3;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, suimon_per_coach, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            battle::decline_battle(&mut battle, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            // assert!(battle.state == 4, 0);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = suimon::battle::EInvalidSuimonCountForCoach)]
    fun transfer_suimon_to_battle() {

        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 3;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, suimon_per_coach, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            battle::accept_battle(&mut battle, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let coach_a_suimon_1 =  suimon::create(100, 100, 10, test_scenario::ctx(scenario));
            let coach_a_suimon_2 =  suimon::create(100, 100, 10, test_scenario::ctx(scenario));
            let coach_a_suimon_3 =  suimon::create(100, 100, 10, test_scenario::ctx(scenario));
            let coach_a_suimon_4 =  suimon::create(100, 100, 10, test_scenario::ctx(scenario));

            transfer::transfer(coach_a_suimon_1, coach_a);
            transfer::transfer(coach_a_suimon_2, coach_a);
            transfer::transfer(coach_a_suimon_3, coach_a);
            transfer::transfer(coach_a_suimon_4, coach_a);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);

            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_2 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_3 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_4 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_2, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_3, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_4, test_scenario::ctx(scenario));

            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_count = battle::suimon_count_for_coach(&battle, coach_a);
            assert!(coach_a_suimon_count == 4, 999);

            test_scenario::return_shared(battle);

        };

        test_scenario::end(scenario_val);

    }

    #[test]
    fun coaches(): (address, address, address) {
        (@0xaaaaaa, @0xbbbbbb, @0xcccccc)
    }
}