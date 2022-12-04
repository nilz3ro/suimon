#[test_only]
module suimon::battle_tests {
    use sui::test_scenario;
    use sui::tx_context;
    use sui::transfer;
    use suimon::battle::{Self, Battle};
    
    #[test]
    fun test_create() {
        let coach_a = @0x1;
        let coach_b = @0x2;
        let referree = @0x3;
        let ctx = tx_context::dummy();
        let battle = battle::create(coach_a, coach_b, &mut ctx);


        transfer::transfer(battle, referree);
    }

    #[test]
    fun test_is_participant() {
        let coach_a = @0x1;
        let coach_b = @0x2;
        let some_rando = @0x3;

        let ctx = tx_context::dummy();
        let battle = battle::create(coach_a, coach_b, &mut ctx);
        let should_be_true = battle::is_participant(&battle, coach_a);
        let should_be_false = battle::is_participant(&battle, some_rando);

        assert!(should_be_true == true, 0);
        assert!(should_be_false == false, 1);

        // todo implement drop behavior.
        transfer::transfer(battle, some_rando);
    }

    #[test]
    fun test_initiate_battle() {

        let coach_a = @0x1;
        let coach_b = @0x2;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
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
        use sui::test_scenario;

        let coach_a = @0x1;
        let coach_b = @0x2;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
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
        use sui::test_scenario;

        let coach_a = @0x1;
        let coach_b = @0x2;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            battle::initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
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
}