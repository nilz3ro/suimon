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


    struct BattleState has key, store {
        id: UID,
        suimon_per_coach: u64,
        coach_a: address,
        coach_b: address,
        coach_a_suimon: vector<Suimon>,
        coach_b_suimon: vector<Suimon>,
        last_turn_taken_by: Option<address>,
        state: u8,
    }

    struct BattleSummary has key, store {
        id: UID,
        coach_a: address,
        coach_b: address,
        suimon_per_coach: u64,
        winner: address
    }

    struct Battle has key, store {
        id: UID,
        battle_state: Option<BattleState>,
        battle_summary: Option<BattleSummary>,
    }


    public fun create_battle(coach_a: address, coach_b: address, suimon_per_coach: u64, ctx: &mut TxContext): Battle {
        let battle_state = create_battle_state(coach_a, coach_b, suimon_per_coach, ctx);
        Battle {
            id: object::new(ctx),
            battle_state: option::some(battle_state),
            battle_summary: option::none() 
        }
    }

    // fun create_battle_summary(): BattleSummary {
    // }

    fun create_battle_state(coach_a: address, coach_b: address, suimon_per_coach: u64, ctx: &mut TxContext): BattleState {
        BattleState {
            id: object::new(ctx),
            coach_a: coach_a,
            coach_b: coach_b,
            coach_a_suimon: vector::empty(),
            coach_b_suimon: vector::empty(),
            suimon_per_coach: suimon_per_coach,
            last_turn_taken_by: option::none(),
            state: SETUP
        }
    }

    public fun is_coach_a(self: &BattleState, addr: address): bool {
        self.coach_a == addr
    }

    public fun is_coach_b(self: &BattleState, addr: address): bool {
        self.coach_b == addr
    }

    public fun opponent(self: &BattleState, addr: address): address {
        assert!(is_participant(self, addr), EInvalidSender);

        if (addr == self.coach_a) {
            self.coach_b
        } else {
            self.coach_a
        }
    }

    public fun is_participant(self: &BattleState, addr: address): bool {
        // self.coach_a == addr || self.coach_b == addr
        is_coach_a(self, addr) || is_coach_b(self, addr)
    }

    public fun battle_is_selecting_suimon(self: &BattleState): bool {
        self.state == SELECTING_SUIMON
    }

    public fun battle_is_active(self: &BattleState): bool {
        self.state == ACTIVE
    }

    public fun battle_is_finished(self: &BattleState): bool {
        self.state == FINISHED
    }

    public fun coach_a_suimon_count(self: &BattleState): u64 {
        vector::length(&self.coach_a_suimon)
    }

    public fun coach_a_suimon_borrow_mut(self: &mut BattleState): &mut vector<Suimon> {
        &mut self.coach_a_suimon
    }

    public fun coach_b_suimon_borrow_mut(self: &mut BattleState): &mut vector<Suimon> {
        &mut self.coach_b_suimon
    }

    public fun coach_a_is_at_capacity(self: &BattleState): bool {
        coach_a_suimon_count(self) == suimon_per_coach(self)
    }

    public fun coach_b_suimon_count(self: &BattleState): u64 {
        vector::length(&self.coach_b_suimon)
    }

    public fun last_turn_taken_by(self: &BattleState): Option<address> {
        self.last_turn_taken_by
    }

    public fun coach_b_is_at_capacity(self: &BattleState): bool {
        coach_b_suimon_count(self) == suimon_per_coach(self)
    }

    public fun suimon_count_for_coach(self: &BattleState, addr: address): u64 {
        assert!(is_participant(self, addr), EInvalidSender);

        if (addr == self.coach_a) {
            vector::length(&self.coach_a_suimon)
        } else {
            vector::length(&self.coach_b_suimon)
        }
    }

    public fun suimon_per_coach(self: &BattleState): u64 {
        self.suimon_per_coach
    }

    public fun commit_battle_accept(self: &mut Battle) {
        let battle_state = option::borrow_mut(&mut self.battle_state);
        assert!(battle_state.state == SETUP, EBattleNotInSetupState);
        battle_state.state = SELECTING_SUIMON;
    }

    public fun commit_battle_decline(self: &mut Battle) {
        let battle_state = option::borrow_mut(&mut self.battle_state);
        assert!(battle_state.state == SETUP, EBattleNotInSetupState);
        battle_state.state = DECLINED;
    }

    public fun all_suimon_fainted(self: &mut BattleState, coach: address): bool {
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

    public fun return_suimon_to_coaches(self: &mut BattleState) {
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
        let battle_state = option::borrow(&battle.battle_state);

        assert!(sender == battle_state.coach_b, EInvalidSender);

        commit_battle_accept(battle);
    }

    public entry fun decline_battle(battle: &mut Battle, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let battle_state = option::borrow(&battle.battle_state);

        assert!(sender == battle_state.coach_b, EInvalidSender);

        commit_battle_decline(battle);
    }

    public entry fun add_suimon_to_battle(battle: &mut Battle, suimon: Suimon, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let battle_state = option::borrow_mut(&mut battle.battle_state);
        let suimon_per_coach = suimon_per_coach(battle_state);

        assert!(is_participant(battle_state, sender), EInvalidSender);
        assert!(battle_is_selecting_suimon(battle_state), EBattleNotInSelectingSuimonState);
        assert!(suimon_count_for_coach(battle_state, sender) + 1 <= suimon_per_coach, EInvalidSuimonCountForCoach);

        if (sender == battle_state.coach_a) {
            vector::push_back(&mut battle_state.coach_a_suimon, suimon);
        } else {
            vector::push_back(&mut battle_state.coach_b_suimon, suimon);
        };

        if (coach_a_is_at_capacity(battle_state) && coach_b_is_at_capacity(battle_state)) {
            // TODO: create state transition functions.
            battle_state.state = ACTIVE;
        };
    }

    // right now we will use rudimentary suimon attacking.
    // in the future there will be attacks and items, a turn will be an object
    // that each coach mutates to add their attack or item to the turn.
    // after the turn is processed, a turn summary will be created and added to the battle.
    public entry fun take_turn(battle: &mut Battle, source_suimon_idx: u64, target_suimon_idx: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        let battle_state = option::borrow_mut(&mut battle.battle_state);
        let opponent = opponent(battle_state, sender);

        assert!(is_participant(battle_state, sender), EInvalidSender);
        assert!(battle_is_active(battle_state), EBattleNotInActiveState);
        assert!(last_turn_taken_by(battle_state) != option::some(sender), EInvalidSender);

        let sender_is_coach_a = is_coach_a(battle_state, sender);

        let source_suimon = if (sender_is_coach_a) {
            vector::remove(&mut battle_state.coach_a_suimon, source_suimon_idx)
        } else {
            vector::remove(&mut battle_state.coach_b_suimon, source_suimon_idx)
        };

        let target_suimon = if (sender_is_coach_a) {
            vector::remove(&mut battle_state.coach_b_suimon, target_suimon_idx)
        } else {
            vector::remove(&mut battle_state.coach_a_suimon, target_suimon_idx)
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
            vector::push_back(&mut battle_state.coach_a_suimon, source_suimon);
            vector::push_back(&mut battle_state.coach_b_suimon, target_suimon);
        } else {
            vector::push_back(&mut battle_state.coach_b_suimon, source_suimon);
            vector::push_back(&mut battle_state.coach_a_suimon, target_suimon);
        };

        battle_state.last_turn_taken_by = option::some(sender); 

        if (all_suimon_fainted(battle_state, opponent)) {
            battle_state.state = FINISHED;
        };
    }

}