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
        state: u8,
    }

    public fun create(coach_a: address, coach_b: address, suimon_per_coach: u64, ctx: &mut TxContext): Battle {
        Battle {
            id: object::new(ctx),
            coach_a,
            coach_b,
            suimon_per_coach,
            coach_a_suimon: vector::empty(),
            coach_b_suimon: vector::empty(),
            state: SETUP,
        }
    }

    public fun is_participant(self: &Battle, addr: address): bool {
        self.coach_a == addr || self.coach_b == addr
    }

    public fun battle_is_selecting_suimon(battle: &Battle): bool {
        battle.state == SELECTING_SUIMON
    }

    public fun suimon_count_for_coach(battle: &Battle, addr: address): u64 {
        assert!(is_participant(battle, addr), EInvalidSender);

        if (addr == battle.coach_a) {
            vector::length(&battle.coach_a_suimon)
        } else {
            vector::length(&battle.coach_b_suimon)
        }
    }  

    public fun commit_battle_accept(self: &mut Battle) {
        assert!(self.state == SETUP, EBattleNotInSetupState);
        self.state = SELECTING_SUIMON;
    }

    public fun commit_battle_decline(self: &mut Battle) {
        assert!(self.state == SETUP, EBattleNotInSetupState);
        self.state = DECLINED;
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

        let battle = create(coach_a, coach_b, suimon_per_coach, ctx);
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

    // TODO: Figure out how specs work here.
    // spec decline_battle {
    //     let battle_state = battle.state;
    //     let sender = ctx.sender;

    //     ensures battle_state == DECLINED;
    //     aborts_if sender != battle.coach_b;
    // }

    public entry fun add_suimon_to_battle(battle: &mut Battle, suimon: Suimon, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);

        assert!(is_participant(battle, sender), EInvalidSender);
        assert!(battle_is_selecting_suimon(battle), EBattleNotInSelectingSuimonState);
        assert!(suimon_count_for_coach(battle, sender) + 1 <= battle.suimon_per_coach, EInvalidSuimonCountForCoach);

        if (sender == battle.coach_a) {
            vector::push_back(&mut battle.coach_a_suimon, suimon);
        } else {
            vector::push_back(&mut battle.coach_b_suimon, suimon);
        }
    }
}