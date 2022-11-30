module suimon::battle {
    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use std::vector;
    // use suimon::suimon::{Self, Suimon};
    use suimon::suimon::Suimon;

    // battle states
    const SETUP: u8 = 0;
    const SELECTING_SUIMON: u8 = 1;
    const ACTIVE: u8 = 2;
    const FINISHED: u8 = 3;

    // error codes
    const EInvalidBattleInitiator: u64 = 1000;

    struct Battle has key {
        id: UID,
        coach_a: address,
        coach_b: address,
        coach_a_suimon: vector<Suimon>,
        coach_b_suimon: vector<Suimon>,
        state: u8,
    }

    public fun create(coach_a: address, coach_b: address, ctx: &mut TxContext): Battle {
        Battle {
            id: object::new(ctx),
            coach_a,
            coach_b,
            coach_a_suimon: vector::empty(),
            coach_b_suimon: vector::empty(),
            state: SETUP,
        }
    }

    // the battle object is shared so coach a and coach b can both interact with it (write to it).
    // we need to ensure that only coach a or coach b are allowed to engage with the battle object,
    // and that only coach a may write to coach a suimon and that only coach b may write to coach b suimon.
    // for now only one of these two coaches may initate a battle, otherwise anyone could create an unlimited
    // number of battles between whichever coaches exist in the system.
    public entry fun initiate_battle(coach_a: address, coach_b: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        if (sender != coach_a && sender != coach_b) {
            abort(EInvalidBattleInitiator)
        };

        let battle = create(coach_a, coach_b, ctx);
        transfer::share_object(battle);
    }

    public fun is_participant(self: &Battle, addr: address): bool {
        self.coach_a == addr || self.coach_b == addr
    }

    // todo: public fun coaches(b: &Battle): (&address, &address)
    

    #[test]
    fun test_create() {
        // use std::debug;

        let referree = @0xc0ffee;
        let coach_a = @0xc0a;
        let coach_b = @0xc0b;
        let ctx = tx_context::dummy();
        let battle = create(coach_a, coach_b, &mut ctx);

        // debug::print(&battle);

        transfer::transfer(battle, referree);
    }

    #[test]
    fun test_is_participant() {
        let some_rando = @0xbabe;
        let coach_a = @0xc0a;
        let coach_b = @0xc0b;

        let ctx = tx_context::dummy();
        let battle = create(coach_a, coach_b, &mut ctx);
        let should_be_true = is_participant(&battle, coach_a);
        let should_be_false = is_participant(&battle, some_rando);

        assert!(should_be_true == true, 0);
        assert!(should_be_false == false, 1);

        // todo implement drop behavior.
        transfer::transfer(battle, some_rando);
    }

    #[test]
    fun test_initiate_battle() {
        use std::debug;
        use sui::test_scenario;

        let coach_a = @0xc0a;
        let coach_b = @0xc0b;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            debug::print(&battle);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }
}