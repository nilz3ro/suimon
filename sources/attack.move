module suimon::attack {
    use sui::object::{Self, UID};
    use sui::tx_context::TxContext;
    use std::string::String;

    struct Attack has key, store {
        id: UID,
        name: String,
        damage: u64,
        heal: bool,
    }

    // TODO: attach attacks to suimon with object tables
    fun create(name: String, damage: u64, ctx: &mut TxContext): Attack {
        Attack {
            id: object::new(ctx),
            name,
            damage,
            heal: false
        }
    }
}