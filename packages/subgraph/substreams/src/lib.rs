mod pb;

use crate::pb::uniswap::types::v1::{Erc20Token, Pools};
use pb::token::price::v1::TokenPrice;
use substreams::pb::substreams::Clock;
use substreams::store::*;
use substreams_entity_change::pb::entity::entity_change::Operation;
use substreams_entity_change::pb::entity::value::Typed;
use substreams_entity_change::pb::entity::EntityChanges;
use substreams_entity_change::tables::Tables;

#[substreams::handlers::store]
pub fn store_uniswap_v3_prices(
    clock: Clock,
    changes: EntityChanges,
    output: StoreSetProto<TokenPrice>,
) {
    let mut changes_iter = changes.entity_changes.iter();
    let change = changes_iter.find(|entity_change| {
        entity_change.entity.as_str() == "TokenHourData"
            && entity_change.operation() == Operation::Create
    });

    match change {
        Some(change) => {
            let mut address: Option<String> = None;
            let mut price: Option<String> = None;
            let mut timestamp: Option<i32> = None;

            let fields_iter = change.fields.iter();
            for field in fields_iter {
                let name = field.name.as_str();
                let value = field.new_value.as_ref().unwrap().typed.as_ref().unwrap();
                match (name, value) {
                    ("token", Typed::String(a)) => {
                        address = Some(a.clone());
                    }
                    ("priceUSD", Typed::Bigdecimal(p)) => {
                        price = Some(p.clone());
                    }
                    ("periodStartUnix", Typed::Int32(t)) => {
                        timestamp = Some(t.clone());
                    }
                    _ => {}
                }

                if address.is_some() && price.is_some() {
                    let token_address = address.unwrap();
                    let time = timestamp
                        .unwrap_or(clock.timestamp.unwrap().seconds as i32)
                        .clone();
                    let token_price = TokenPrice {
                        token: token_address.clone(),
                        price_usd: price.unwrap(),
                        timestamp: time.to_string(),
                    };
                    output.set(time as u64, format!("TokenPrice:{token_address}"), &token_price);

                    break;
                }
            }
        }
        None => {}
    }
}

#[substreams::handlers::map]
pub fn graph_out(
    pools_created: Pools,
    prices_store: StoreGetProto<TokenPrice>,
) -> Result<EntityChanges, substreams::errors::Error> {
    let mut tables = Tables::new();

    for pool in pools_created.pools {
        let token0 = pool.token0.as_ref().unwrap();
        let token1 = pool.token1.as_ref().unwrap();

        let token0_price = prices_store.get_last(format!("TokenPrice:0x{}", token0.address));
        let token1_price = prices_store.get_last(format!("TokenPrice:0x{}", token1.address));

        if token0_price.is_some() {
            set_token_data(&mut tables, &token0_price.unwrap(), &token0);
        }
        if token1_price.is_some() {
            set_token_data(&mut tables, &token1_price.unwrap(), &token1);
        }
    }

    Ok(tables.to_entity_changes())
}

fn set_token_data(tables: &mut Tables, token_price: &TokenPrice, token: &Erc20Token) {
    let address = fmt_address(&token.address);
    tables
        .create_row("TokenPrice", &address)
        .set("token", &address)
        .set("priceUSD", &token_price.price_usd)
        .set("timestamp", &token_price.timestamp);
}

fn fmt_address(address: &str) -> String {
    format!("0x{}", address)
}
