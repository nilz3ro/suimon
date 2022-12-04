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
    const EInvalidOpponent: u64 = 1001;
    const EInvalidSender: u64 = 1002;
    const EBattleAlreadyAccepted: u64 = 1003;
    const EBattleNotInSelectingSuimonState: u64 = 1004;


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

    public fun is_participant(self: &Battle, addr: address): bool {
        self.coach_a == addr || self.coach_b == addr
    }


    // TODO: come up with a naming convention for entry functions that transition battle state.
    // maybe something like <verb>_battle.
    public fun battle_accepted(self: &mut Battle) {
        assert!(self.state == SETUP, 0);
        // TODO: extract an action system,
        //  we need to be able to enforce that a given state is traversible through
        //  a given action.
        self.state = SELECTING_SUIMON;
    }

    // todo: public fun coaches(b: &Battle): (&address, &address)

    // the battle object is shared so coach a and coach b can both interact with it (write to it).
    // we need to ensure that only coach a or coach b are allowed to engage with the battle object,
    // and that only coach a may write to coach a suimon and that only coach b may write to coach b suimon.
    // for now only one of these two coaches may initate a battle, otherwise anyone could create an unlimited
    // number of battles between whichever coaches exist in the system.
    public entry fun initiate_battle(coach_a: address, coach_b: address, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        if (sender != coach_a) {
            abort(EInvalidBattleInitiator)
        };
        if (coach_a == coach_b) {
            abort(EInvalidOpponent)
        };

        let battle = create(coach_a, coach_b, ctx);
        transfer::share_object(battle);
    }

    public entry fun accept_battle(battle: &mut Battle, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        if (sender != battle.coach_b) {
            abort(EInvalidSender)
        };

        battle_accepted(battle);
    }

    public entry fun decline_battle(battle: Battle, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        if (sender != battle.coach_b) {
            abort(EInvalidSender)
        };
        if (battle.state != SETUP) {
            abort(EBattleAlreadyAccepted)
        };

        let Battle {id, coach_a: _, coach_b: _, coach_a_suimon, coach_b_suimon, state: _ } = battle;

        vector::destroy_empty(coach_a_suimon);
        vector::destroy_empty(coach_b_suimon);
        object::delete(id);
    }

    public entry fun add_suimon_to_battle(battle: &mut Battle, suimon: Suimon, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        if (sender != battle.coach_a && sender != battle.coach_b) {
            abort(EInvalidSender)
        };
        if (battle.state != SELECTING_SUIMON) {
            abort(EBattleNotInSelectingSuimonState)
        };
        if (sender == battle.coach_a) {
            vector::push_back(&mut battle.coach_a_suimon, suimon);
        } else {
            vector::push_back(&mut battle.coach_b_suimon, suimon);
        }
    }


    #[test]
    fun test_create() {
        let referree = @0xc0ffee;
        let coach_a = @0xc0a;
        let coach_b = @0xc0b;
        let ctx = tx_context::dummy();
        let battle = create(coach_a, coach_b, &mut ctx);


        transfer::transfer(battle, referree);
    }

    #[test]
    fun test_is_participant() {
        let some_rando = @0xbabe;
        let coach_a = @0xabcd;
        let coach_b = @0xdcba;

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
        use sui::test_scenario;

        let coach_a = @0xabcd;
        let coach_b = @0xdbca;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            assert!(battle.state == 0, 2);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_accept_battle() {
        use sui::test_scenario;

        let coach_a = @0xabcd;
        let coach_b = @0xdbca;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            accept_battle(&mut battle, test_scenario::ctx(scenario));
            assert!(battle.state == 1, 3);
            test_scenario::return_shared(battle);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_decline_battle() {
        use sui::test_scenario;

        let coach_a = @0xabcd;
        let coach_b = @0xdbca;

        let scenario_val = test_scenario::begin(coach_a);
        let scenario = &mut scenario_val;
        {
            initiate_battle(coach_a, coach_b, test_scenario::ctx(scenario))
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            let battle = test_scenario::take_shared<Battle>(scenario);
            decline_battle(battle, test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, coach_b);
        {
            assert!(!test_scenario::has_most_recent_for_sender<Battle>(scenario), 999);
        };

        test_scenario::end(scenario_val);
    }

    // #[test]
    // fun test_add_suimon_to_battle() {
    //     let rando = @0xc0ffee;
    //     let coach_a = @0xabcd;
    //     let coach_b = @0xdbca;

    //     let ctx = tx_context::dummy();
    // }
}