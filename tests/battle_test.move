#[test_only]
module suimon::battle_tests {
    use std::vector;

    use sui::test_scenario;
    use sui::tx_context;
    use sui::transfer;

    use suimon::battle::{Self, Battle};
    use suimon::suimon::{Self, Suimon};
    use suimon::hatchery::{Self, CreateCap};
    
    #[test]
    fun test_create() {
        let (coach_a, coach_b, referree) = coaches();
        let ctx = tx_context::dummy();
        let battle = battle::create_battle(coach_a, coach_b, 3, &mut ctx);

        transfer::transfer(battle, referree);
    }

    #[test]
    fun test_is_participant() {
        let (coach_a, coach_b, other) = coaches();
        let suimon_per_coach = 3;

        let ctx = tx_context::dummy();
        let battle = battle::create_battle(coach_a, coach_b, suimon_per_coach, &mut ctx);
        let should_be_true = battle::is_participant(&battle, coach_a);
        let should_be_false = battle::is_participant(&battle, other);

        assert!(should_be_true == true, 0);
        assert!(should_be_false == false, 1);

        // transfer somewhere so that the move engine won't dump on us.
        transfer::transfer(battle, other);
    }

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
            hatchery::grant_create_cap(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);
            
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, create_cap);
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
    fun transfer_suimon_to_battle_transitions_states() {
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
            hatchery::grant_create_cap(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);

            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));

            hatchery::hatch_suimon(&create_cap, coach_b, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_b, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_b, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, create_cap);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);

            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_2 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_3 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_2, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_3, test_scenario::ctx(scenario));

            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);

            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_2 = test_scenario::take_from_sender<Suimon>(scenario);
            let suimon_3 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_2, test_scenario::ctx(scenario));
            battle::add_suimon_to_battle(&mut battle, suimon_3, test_scenario::ctx(scenario));

            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_count = battle::coach_a_suimon_count(&battle);
            let coach_b_suimon_count = battle::coach_b_suimon_count(&battle);

            assert!(coach_a_suimon_count == battle::suimon_per_coach(&battle), 998);
            assert!(coach_b_suimon_count == battle::suimon_per_coach(&battle), 999);
            assert!(battle::battle_is_active(&battle), 1000);

            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun turn_based_attacks() {
        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 1;

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
            hatchery::grant_create_cap(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);

            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_b, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, create_cap);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_count = battle::coach_a_suimon_count(&battle);
            let coach_b_suimon_count = battle::coach_b_suimon_count(&battle);

            assert!(coach_a_suimon_count == battle::suimon_per_coach(&battle), 998);
            assert!(coach_b_suimon_count == battle::suimon_per_coach(&battle), 999);
            assert!(battle::battle_is_active(&battle), 1000);

            test_scenario::return_shared(battle);

        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);

            let coach_a_suimon_index = 0;
            let coach_b_suimon_index = 0;

            battle::take_turn(&mut battle, coach_a_suimon_index, coach_b_suimon_index, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
       
    }

    #[test]
    fun test_suimon_fainting() {
        let (coach_a, coach_b, _) = coaches();
        let suimon_per_coach = 1;

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
            hatchery::grant_create_cap(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);

            hatchery::hatch_suimon(&create_cap, coach_a, test_scenario::ctx(scenario));
            hatchery::hatch_suimon(&create_cap, coach_b, test_scenario::ctx(scenario));

            test_scenario::return_to_sender(scenario, create_cap);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let suimon_1 = test_scenario::take_from_sender<Suimon>(scenario);

            battle::add_suimon_to_battle(&mut battle, suimon_1, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_count = battle::coach_a_suimon_count(&battle);
            let coach_b_suimon_count = battle::coach_b_suimon_count(&battle);

            assert!(coach_a_suimon_count == battle::suimon_per_coach(&battle), 998);
            assert!(coach_b_suimon_count == battle::suimon_per_coach(&battle), 999);
            assert!(battle::battle_is_active(&battle), 1000);

            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_index = 0;
            let coach_b_suimon_index = 0;

            battle::take_turn(&mut battle, coach_a_suimon_index, coach_b_suimon_index, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            let coach_a_suimon_mut = battle::coach_a_suimon_borrow_mut(&mut battle);
            let maybe_fainted_suimon = vector::remove<Suimon>(coach_a_suimon_mut, 0);

            // we perform this assertion here because we need to put the suimon back in the battle vector
            // so that we can check if the battle is finished
            assert!(suimon::is_fainted(&maybe_fainted_suimon), 909);
            vector::push_back(coach_a_suimon_mut, maybe_fainted_suimon);

            let battle_is_finished = battle::battle_is_finished(&battle);
            let all_coach_a_suimon_fainted = battle::all_suimon_fainted(&mut battle, coach_a);

            assert!(all_coach_a_suimon_fainted, 910);
            assert!(battle_is_finished, 911);


            test_scenario::return_shared(battle);
        };
        test_scenario::next_tx(scenario, coach_a);
        {
            // use std::debug;
            // find out if the battle has been destroyed or not.
            let battle = test_scenario::take_shared<Battle>(scenario);

            // debug::print(&battle);

            battle::return_suimon_to_coaches(&mut battle);
            // battle::finish_battle(battle, test_scenario::ctx(scenario));
            test_scenario::return_shared(battle);


        };

        test_scenario::end(scenario_val);
    }

    fun coaches(): (address, address, address) {
        (@0xaaaaaa, @0xbbbbbb, @0xcccccc)
    }
}