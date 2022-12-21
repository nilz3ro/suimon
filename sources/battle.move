module suimon::battle {
    use std::vector;
    use std::option::{Self, Option};

    use sui::transfer;
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use suimon::suimon::{Self, Suimon};
    // use suimon::suimon::Suimon;

    // battle states
    const SETUP: u8 = 0;
    const SELECTING_SUIMON: u8 = 1;
    const ACTIVE: u8 = 2;
    const FINISHED: u8 = 3;
    const DECLINED: u8 = 4;

    // error codes
    const EInvalidBattleInitiator: u64 = 1000;
    const EInvalidOpponent: u64 = 1001;
    const EInvalidSender: u64 = 1002;
    const EBattleAlreadyAccepted: u64 = 1003;
    const EBattleNotInSetupState: u64 = 1004;
    const EBattleNotInSelectingSuimonState: u64 = 1005;
    const EBattleNotInActiveState: u64 = 1006;
    const EBattleNotInFinishedState: u64 = 1007;
    const EBattleNotInDeclinedState: u64 = 1008;
    const EInvalidSuimonCountForCoach: u64 = 1009;


    struct Battle has key {
        id: UID,
        coach_a: address,
        coach_b: address,
        suimon_per_coach: u64,
        coach_a_suimon: vector<Suimon>,
        coach_b_suimon: vector<Suimon>,
        // TODO: add a turns vec of turn summary objects.
        // turns: vector<TurnSummary>
        // last_turn_summary: TurnSummary,
        //
        // TODO: add a function that derives which player should move first
        // next_turn_coach_address: Option<address>,
        last_turn_taken_by: Option<address>,
        state: u8,
    }

    struct BattleSummary has key {
        id: UID,
        coach_a: address,
        coach_b: address,
        suimon_per_coach: u64,
        winner: address
    }

    public fun create_battle(coach_a: address, coach_b: address, suimon_per_coach: u64, ctx: &mut TxContext): Battle {
        Battle {
            id: object::new(ctx),
            coach_a,
            coach_b,
            suimon_per_coach,
            coach_a_suimon: vector::empty(),
            coach_b_suimon: vector::empty(),
            last_turn_taken_by: option::none(),
            state: SETUP,
        }
    }

    fun create_battle_summary(battle: &Battle, winner: address, ctx: &mut TxContext): BattleSummary {
        BattleSummary {
            id: object::new(ctx),
            coach_a: battle.coach_a,
            coach_b: battle.coach_b,
            suimon_per_coach: battle.suimon_per_coach,
            winner,
        }
    }

    public fun is_coach_a(self: &Battle, addr: address): bool {
        self.coach_a == addr
    }

    public fun is_coach_b(self: &Battle, addr: address): bool {
        self.coach_b == addr
    }

    public fun opponent(self: &Battle, addr: address): address {
        assert!(is_participant(self, addr), EInvalidSender);

        if (addr == self.coach_a) {
            self.coach_b
        } else {
            self.coach_a
        }
    }

    public fun is_participant(self: &Battle, addr: address): bool {
        // self.coach_a == addr || self.coach_b == addr
        is_coach_a(self, addr) || is_coach_b(self, addr)
    }

    public fun battle_is_selecting_suimon(battle: &Battle): bool {
        battle.state == SELECTING_SUIMON
    }

    public fun battle_is_active(battle: &Battle): bool {
        battle.state == ACTIVE
    }

    public fun battle_is_finished(battle: &Battle): bool {
        battle.state == FINISHED
    }

    public fun coach_a_suimon_count(battle: &Battle): u64 {
        vector::length(&battle.coach_a_suimon)
    }

    public fun coach_a_suimon_borrow_mut(battle: &mut Battle): &mut vector<Suimon> {
        &mut battle.coach_a_suimon
    }

    public fun coach_b_suimon_borrow_mut(battle: &mut Battle): &mut vector<Suimon> {
        &mut battle.coach_b_suimon
    }

    public fun coach_a_is_at_capacity(battle: &Battle): bool {
        coach_a_suimon_count(battle) == suimon_per_coach(battle)
    }

    public fun coach_b_suimon_count(battle: &Battle): u64 {
        vector::length(&battle.coach_b_suimon)
    }

    public fun last_turn_taken_by(battle: &Battle): Option<address> {
        battle.last_turn_taken_by
    }

    public fun coach_b_is_at_capacity(battle: &Battle): bool {
        coach_b_suimon_count(battle) == suimon_per_coach(battle)
    }

    public fun suimon_count_for_coach(battle: &Battle, addr: address): u64 {
        assert!(is_participant(battle, addr), EInvalidSender);

        if (addr == battle.coach_a) {
            vector::length(&battle.coach_a_suimon)
        } else {
            vector::length(&battle.coach_b_suimon)
        }
    }

    public fun suimon_per_coach(battle: &Battle): u64 {
        battle.suimon_per_coach
    }

    public fun commit_battle_accept(self: &mut Battle) {
        assert!(self.state == SETUP, EBattleNotInSetupState);
        self.state = SELECTING_SUIMON;
    }

    public fun commit_battle_decline(self: &mut Battle) {
        assert!(self.state == SETUP, EBattleNotInSetupState);
        self.state = DECLINED;
    }

    public fun all_suimon_fainted(self: &mut Battle, coach: address): bool {
        assert!(is_participant(self, coach), EInvalidSender);

        let suimon_per_coach = suimon_per_coach(self);
        let coach_is_coach_a = is_coach_a(self, coach);

        let num_visited: u64 = 0;
        let num_fainted: u64 = 0;

        if (coach_is_coach_a) {
            // TODO: extract this into a function
            let coach_a_suimon_mut = coach_a_suimon_borrow_mut(self);
            while (num_visited < suimon_per_coach) {
                let suimon_being_inspected = vector::remove<Suimon>(coach_a_suimon_mut, num_visited);

                if (suimon::is_fainted(&suimon_being_inspected)) {
                    num_fainted = num_fainted + 1;
                };
                vector::push_back(coach_a_suimon_mut, suimon_being_inspected);

                num_visited = num_visited + 1;
            };
        } else {
            let coach_b_suimon_mut = coach_b_suimon_borrow_mut(self);
            while (num_visited < suimon_per_coach) {
                let suimon_being_inspected = vector::remove<Suimon>(coach_b_suimon_mut, num_visited);

                if (suimon::is_fainted(&suimon_being_inspected)) {
                    num_fainted = num_fainted + 1;
                };
                vector::push_back(coach_b_suimon_mut, suimon_being_inspected);

                num_visited = num_visited + 1;
            };
        };

        num_fainted == num_visited
    }

    public fun return_suimon_to_coaches(self: &mut Battle) {
        let coach_a = self.coach_a;
        let coach_a_suimon_mut = coach_a_suimon_borrow_mut(self);

        while (vector::length(coach_a_suimon_mut) > 0) {
            let suimon_being_returned = vector::pop_back(coach_a_suimon_mut);
            transfer::transfer(suimon_being_returned, coach_a);
        };

        let coach_b = self.coach_b;
        let coach_b_suimon_mut = coach_b_suimon_borrow_mut(self);
        while (vector::length(coach_b_suimon_mut) > 0) {
            let suimon_being_returned = vector::pop_back(coach_b_suimon_mut);
            transfer::transfer(suimon_being_returned, coach_b);
        };
    }

    // the battle object is shared so coach a and coach b can both interact with it (write to it).
    // we need to ensure that only coach a or coach b are allowed to engage with the battle object,
    // and that only coach a may write to coach a suimon and that only coach b may write to coach b suimon.
    // for now only one of these two coaches may initate a battle, otherwise anyone could create an unlimited
    // number of battles between whichever coaches exist in the system.
    public entry fun initiate_battle(coach_a: address, coach_b: address, suimon_per_coach: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(sender == coach_a, EInvalidBattleInitiator);
        assert!(coach_a != coach_b, EInvalidBattleInitiator);

        let battle = create_battle(coach_a, coach_b, suimon_per_coach, ctx);
        transfer::share_object(battle);
    }

    public entry fun accept_battle(battle: &mut Battle, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(sender == battle.coach_b, EInvalidSender);

        commit_battle_accept(battle);
    }

    public entry fun decline_battle(battle: &mut Battle, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(sender == battle.coach_b, EInvalidSender);

        commit_battle_decline(battle);
    }

    public entry fun add_suimon_to_battle(battle: &mut Battle, suimon: Suimon, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let suimon_per_coach = suimon_per_coach(battle);

        assert!(is_participant(battle, sender), EInvalidSender);
        assert!(battle_is_selecting_suimon(battle), EBattleNotInSelectingSuimonState);
        assert!(suimon_count_for_coach(battle, sender) + 1 <= suimon_per_coach, EInvalidSuimonCountForCoach);

        if (sender == battle.coach_a) {
            vector::push_back(&mut battle.coach_a_suimon, suimon);
        } else {
            vector::push_back(&mut battle.coach_b_suimon, suimon);
        };

        if (coach_a_is_at_capacity(battle) && coach_b_is_at_capacity(battle)) {
            // TODO: create state transition functions.
            battle.state = ACTIVE;
        };
    }

    // right now we will use rudimentary suimon attacking.
    // in the future there will be attacks and items, a turn will be an object
    // that each coach mutates to add their attack or item to the turn.
    // after the turn is processed, a turn summary will be created and added to the battle.
    public entry fun take_turn(battle: &mut Battle, source_suimon_idx: u64, target_suimon_idx: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let opponent = opponent(battle, sender);

        assert!(is_participant(battle, sender), EInvalidSender);
        assert!(battle_is_active(battle), EBattleNotInActiveState);
        assert!(last_turn_taken_by(battle) != option::some(sender), EInvalidSender);

        let sender_is_coach_a = is_coach_a(battle, sender);

        let source_suimon = if (sender_is_coach_a) {
            vector::remove(&mut battle.coach_a_suimon, source_suimon_idx)
        } else {
            vector::remove(&mut battle.coach_b_suimon, source_suimon_idx)
        };

        let target_suimon = if (sender_is_coach_a) {
            vector::remove(&mut battle.coach_b_suimon, target_suimon_idx)
        } else {
            vector::remove(&mut battle.coach_a_suimon, target_suimon_idx)
        };

        // make a suimon attack another suimon
        suimon::attack(&mut source_suimon, &mut target_suimon);
        // TODO: If the target suimon has fainted, emit an event.
        // if (suimon::is_fainted(&target_suimon)) {
        //     abort(1111)
        // };

        // finally, return the suimon to their respective vectors.
        // TODO: preserve the order of the suimon in the vectors.
        if (sender_is_coach_a) {
            vector::push_back(&mut battle.coach_a_suimon, source_suimon);
            vector::push_back(&mut battle.coach_b_suimon, target_suimon);
        } else {
            vector::push_back(&mut battle.coach_b_suimon, source_suimon);
            vector::push_back(&mut battle.coach_a_suimon, target_suimon);
        };

        battle.last_turn_taken_by = option::some(sender); 

        if (all_suimon_fainted(battle, opponent)) {
            battle.state = FINISHED;
        };
    }

    // TODO: wait until the Mysten team has finished the PR that allows shared
    // objects to be deleted.
    public entry fun finish_battle(battle: Battle, ctx: &mut TxContext) {
        use std::debug;

        let sender = tx_context::sender(ctx);

        assert!(is_participant(&battle, sender), EInvalidSender);
        assert!(battle_is_finished(&battle), EBattleNotInFinishedState);

        // return_suimon_to_coaches(&mut battle);

        let Battle {id, coach_a: _, coach_b: _, suimon_per_coach: _, coach_a_suimon, coach_b_suimon, last_turn_taken_by: _, state: _ } = battle;
        // return_suimon_to_coaches(&mut battle);


        // TODO: before we destroy the battle object,
        // let's create an immutable digest of the battle called BattleSummary.

        let coach_a_suimon_length = vector::length(&coach_a_suimon);
        let coach_b_suimon_length = vector::length(&coach_b_suimon);

        debug::print(&coach_a_suimon_length);
        debug::print(&coach_b_suimon_length);

        vector::destroy_empty(coach_a_suimon);
        vector::destroy_empty(coach_b_suimon);

        object::delete(id);

        
    }
}