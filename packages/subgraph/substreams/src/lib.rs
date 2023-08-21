mod pb;

use crate::pb::uniswap::types::v1::Erc20Token;
use hex::FromHex;
use pb::token::price::v1::TokenPrice;
use substreams::pb::substreams::Clock;
use substreams_entity_change::pb::entity::value::Typed;
use substreams_entity_change::pb::entity::{EntityChange, EntityChanges};
use substreams_entity_change::tables::Tables;

#[substreams::handlers::map]
pub fn map_token_prices(
    clock: Clock,
    entity_changes: EntityChanges,
) -> Result<EntityChanges, substreams::errors::Error> {
    let mut tables = Tables::new();

    let changes_iter = entity_changes.entity_changes;
    for item in changes_iter {
        match item.entity.as_str() {
            "Token" => {
                let token = get_token_from_entity(&item);
                if let Some(t) = token {
                    set_token_data(&mut tables, &t);
                }
            }
            "TokenHourData" => {
                let token_price = get_token_price_from_entity(&clock, &item);
                if let Some(tp) = token_price {
                    set_token_price(&mut tables, &tp);
                }
            }
            _ => {}
        }
    }

    Ok(tables.to_entity_changes())
}
fn get_token_from_entity(change: &EntityChange) -> Option<Erc20Token> {
    let address: String = change.clone().id;
    let mut symbol: Option<String> = None;
    let mut name: Option<String> = None;
    let mut decimals: Option<String> = None;

    let fields_iter = change.fields.iter();
    for field in fields_iter {
        let field_name = field.name.as_str();
        let field_value = field.new_value.as_ref().unwrap().typed.as_ref().unwrap();
        match (field_name, field_value) {
            ("symbol", Typed::String(a)) => {
                symbol = Some(fmt_address(a));
            }
            ("name", Typed::String(p)) => {
                name = Some(p.clone());
            }
            ("decimals", Typed::Bigint(t)) => {
                decimals = Some(t.clone());
            }
            _ => {}
        }

        match (symbol.clone(), name.clone(), decimals.clone()) {
            (Some(symbol), Some(name), Some(decimals)) => {
                return Some(Erc20Token {
                    address,
                    symbol,
                    name,
                    decimals: decimals.parse().unwrap(),
                    total_supply: "".to_string(),
                    whitelist_pools: vec![],
                })
            }
            _ => {}
        }
    }
    None
}
fn get_token_price_from_entity(clock: &Clock, change: &EntityChange) -> Option<TokenPrice> {
    let mut address: Option<String> = None;
    let mut price: Option<String> = None;
    let mut timestamp: u64 = clock.timestamp.clone().unwrap().seconds as u64;

    let fields_iter = change.fields.iter();
    for field in fields_iter {
        let name = field.name.as_str();
        let value = field.new_value.as_ref().unwrap().typed.as_ref().unwrap();
        match (name, value) {
            ("token", Typed::String(a)) => {
                address = Some(fmt_address(a));
            }
            ("priceUSD", Typed::Bigdecimal(p)) => {
                price = Some(p.clone());
            }
            ("periodStartUnix", Typed::Int32(t)) => {
                timestamp = t.clone() as u64;
            }
            _ => {}
        }

        match (address.clone(), price.clone()) {
            (Some(token), Some(price_usd)) => {
                return Some(TokenPrice {
                    token,
                    price_usd,
                    timestamp,
                })
            }
            _ => {}
        }
    }
    None
}

fn set_token_data(tables: &mut Tables, token: &Erc20Token) {
    let address = fmt_address(&token.address);
    tables
        .create_row("Token", &address)
        .set("address", fmt_address_to_bytes_vec(&token.address))
        .set("type", "ERC20")
        .set("symbol", &token.symbol)
        .set("name", &token.name)
        .set("decimals", token.decimals);
}
fn set_token_price(tables: &mut Tables, token_price: &TokenPrice) {
    let address = fmt_address(&token_price.token);
    tables
        .create_row("TokenPrice", &address)
        .set("token", &address)
        .set_bigdecimal("priceUSD", &token_price.price_usd)
        .set("timestamp", token_price.timestamp);
}

fn fmt_address(address: &str) -> String {
    if address.starts_with("0x") {
        return address.to_string();
    }
    format!("0x{address}")
}

fn fmt_address_to_bytes_vec(address: &str) -> Vec<u8> {
    let mut addr = address;
    if addr.starts_with("0x") {
        addr = &addr[2..];
    }
    Vec::from_hex(addr).unwrap()
}
