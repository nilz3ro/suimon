module suimon::suimon {
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    struct Suimon has key, store {
        id: UID,
        hp: u64,
        remaining_hp: u64,
        attack_power: u64, 
        attack_uses: u8,
        remaining_attack_uses: u8,
    }

    const EAttackWithZeroRemainingHP: u64 = 0;
    const EAttackWithZeroRemainingAttackUses: u64 = 1;

    public fun create(hp: u64, attack_power: u64, attack_uses: u8, ctx: &mut TxContext): Suimon {
        Suimon {
            id: object::new(ctx),
            remaining_hp: hp,
            hp,
            attack_power,
            remaining_attack_uses: attack_uses,
            attack_uses,
        }
    }

    public fun attack(self: &mut Suimon, target: &mut Suimon) {
        target.remaining_hp = target.remaining_hp - use_attack(self);

        // if (target.remaining_hp == 0) {
            // consider creating a new sui coin for XP that we transfer
            // to the attacker when they "faint" an opponent.
        // }
    }

    public fun use_attack(self: &mut Suimon): u64 {
        if (self.remaining_hp == 0) {
            abort(EAttackWithZeroRemainingHP)
        };
        if (self.remaining_attack_uses == 0) {
            abort(EAttackWithZeroRemainingAttackUses)
        };

        self.remaining_attack_uses = self.remaining_attack_uses - 1;
        self.attack_power
    } 

    public fun hp(self: &Suimon): u64 {
        self.hp
    }

    public fun remaining_hp(self: &Suimon): u64 {
        self.remaining_hp
    }

    public fun attack_power(self: &Suimon): u64 {
        self.attack_power
    }

    public fun attack_uses(self: &Suimon): u8 {
        self.attack_uses
    }

    public fun remaining_attack_uses(self: &Suimon): u8 {
        self.remaining_attack_uses
    }

    fun heal(self: &mut Suimon, amount: u64) {
        self.remaining_hp = self.remaining_hp + amount;
    }

    fun full_heal(self: &mut Suimon) {
        self.remaining_hp = self.hp;
    }

    // make a suimon creator module that calls this with sensible constraints,
    // if we leave this as a public entry function, anyone can create an overpowered suimon.
    public entry fun create_suimon(max_hp: u64, attack_power: u64, attack_uses: u8, ctx: &mut TxContext) {
        let suimon = create(max_hp, attack_power, attack_uses, ctx);
        transfer::transfer(suimon, tx_context::sender(ctx));
    }

    #[test]
    fun test_create_suimon() {
        use sui::test_scenario;

        let creator = @0xc0ffee;

        let scenario_val = test_scenario::begin(creator);
        let scenario = &mut scenario_val;
        {
            create_suimon(100, 100, 10, test_scenario::ctx(scenario));
        };

        // make sure newly created suimon belongs to creator;
        test_scenario::next_tx(scenario, creator);
        {
            let s = test_scenario::take_from_sender<Suimon>(scenario);
            assert!(s.hp == 100 && s.remaining_hp == 100, 0);
            test_scenario::return_to_sender(scenario, s);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun test_attack() {
        use sui::tx_context;

        let receiver = @0xc0ffee;

        let ctx = tx_context::dummy();
        let suimon = create(100, 100, 10, &mut ctx);
        let another_suimon = create(100, 100, 10, &mut ctx);

        attack(&mut suimon, &mut another_suimon);
        assert!(another_suimon.remaining_hp == 0, 0);

        transfer::transfer(suimon, receiver);
        transfer::transfer(another_suimon, receiver);
    }
}