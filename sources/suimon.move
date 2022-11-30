module suimon::suimon {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Suimon has key, store {
        id: UID,
        hp: u64,
        max_hp: u64,
        attack_power: u8
    }

    public fun create(max_hp: u64, attack_power: u8, ctx: &mut TxContext): Suimon {
        Suimon {
            id: object::new(ctx),
            hp: max_hp,
            max_hp,
            attack_power
        }
    }

    public entry fun create_suimon(max_hp: u64, attack_power: u8, ctx: &mut TxContext) {
        let suimon = create(max_hp, attack_power, ctx);
        transfer::transfer(suimon, tx_context::sender(ctx));
    }

    #[test]
    fun test_create_suimon() {
        use sui::test_scenario;

        let creator = @0xc0ffee;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;
        {
            create_suimon(100, 100, test_scenario::ctx(scenario));
        };

        // make sure newly created suimon belongs to creator;
        test_scenario::next_tx(scenario, creator);
        {
            let s = test_scenario::take_from_sender<Suimon>(scenario);
            assert!(s.hp == 100 && s.max_hp == 100, 0);
            test_scenario::return_to_sender(scenario, s);
        };

        test_scenario::end(scenario_val);
    }
}