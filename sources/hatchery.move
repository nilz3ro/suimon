module suimon::hatchery {
    // TODO: The hatchery should be responsible for creating different types
    // of suimon, with different stats and abilities.

    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::event;

    use suimon::suimon;

    // event struct
    struct SuimonHatched has copy, drop {}

    struct CreateCap has key {
        id: UID
    }

    fun init(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let create_cap = CreateCap {
            id: object::new(ctx)
        };

        transfer::transfer(create_cap, sender);
    }

    public entry fun hatch_suimon(_create_cap: &CreateCap, recipient: address, ctx: &mut TxContext) {
        // create a new suimon
        
        let suimon = suimon::create(100, 100, 10, b"http://example.com", ctx);

        // transfer the suimon to the sender
        transfer::transfer(suimon, recipient);
        event::emit(SuimonHatched {});
    }

    #[test_only]
    public fun grant_create_cap(ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let create_cap = CreateCap {
            id: object::new(ctx)
        };

        transfer::transfer(create_cap, sender);
    }

    #[test]
    fun test_init() {
        use sui::test_scenario;

        let creator = @0xc0ff33;
        let another_creator = @0xc0ffee;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;
        {
            init(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, creator);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);

            test_scenario::return_to_sender(scenario, create_cap)
        };
        test_scenario::next_tx(scenario, another_creator);
        {
            grant_create_cap(test_scenario::ctx(scenario));
        };
        test_scenario::next_tx(scenario, another_creator);
        {
            let create_cap = test_scenario::take_from_sender<CreateCap>(scenario);

            test_scenario::return_to_sender(scenario, create_cap);
        };

        test_scenario::end(scenario_val);
    }

}