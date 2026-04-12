function _parse_account(o::JSON3.Object)
    return Account(
        String(o.id),
        String(o.account_number),
        String(o.status),
        String(o.currency),
        _parse_float_default(get(o, :cash, "0")),
        _parse_float_default(get(o, :buying_power, "0")),
        _parse_float_default(get(o, :portfolio_value, "0")),
        _parse_float_default(get(o, :equity, "0")),
        _parse_float_default(get(o, :last_equity, "0")),
        Bool(get(o, :pattern_day_trader, false)),
        Bool(get(o, :trading_blocked, false)),
        Bool(get(o, :transfers_blocked, false)),
        Bool(get(o, :account_blocked, false)),
        o,
    )
end

"""
    get_account(client)

Fetch the authenticated account summary (cash, equity, buying power, status flags).
"""
function get_account(client::AlpacaClient)
    return _parse_account(_trading_get(client, "/account"))
end
