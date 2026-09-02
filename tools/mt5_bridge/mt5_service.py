"""
AURA Trading Assistant — MetaTrader 5 (MT5) Local Bridge Service
Port: 127.0.0.1:8088
"""

import sys
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Attempt MetaTrader5 import safely
try:
    import MetaTrader5 as mt5
    MT5_AVAILABLE = True
except ImportError:
    MT5_AVAILABLE = False


def _check_mt5_init():
    if not MT5_AVAILABLE:
        return False, "MetaTrader5 Python package is not installed."
    if not mt5.initialize():
        return False, f"MT5 terminal initialization failed: {mt5.last_error()}"
    return True, "Connected to MT5 Terminal."


@app.route('/health', methods=['GET'])
def health():
    connected, msg = _check_mt5_init()
    if connected:
        terminal_info = mt5.terminal_info()
        return jsonify({
            "status": "online",
            "connected": True,
            "message": msg,
            "terminal": terminal_info._asdict() if terminal_info else None
        })
    else:
        return jsonify({
            "status": "offline",
            "connected": False,
            "message": msg
        }), 200


@app.route('/account', methods=['GET'])
def account():
    connected, msg = _check_mt5_init()
    if not connected:
        return jsonify({"status": "error", "message": msg}), 500

    acc = mt5.account_info()
    if acc is None:
        return jsonify({"status": "error", "message": f"Failed to retrieve account info: {mt5.last_error()}"}), 500

    return jsonify({
        "status": "success",
        "login": acc.login,
        "balance": str(acc.balance),
        "equity": str(acc.equity),
        "margin": str(acc.margin),
        "free_margin": str(acc.margin_free),
        "currency": acc.currency,
        "server": acc.server,
        "company": acc.company
    })


@app.route('/positions', methods=['GET'])
def positions():
    connected, msg = _check_mt5_init()
    if not connected:
        return jsonify({"status": "error", "message": msg}), 500

    pos_list = mt5.positions_get()
    if pos_list is None:
        return jsonify({"status": "success", "positions": []})

    result = []
    for p in pos_list:
        result.append({
            "ticket": p.ticket,
            "symbol": p.symbol,
            "type": "BUY" if p.type == mt5.ORDER_TYPE_BUY else "SELL",
            "volume": str(p.volume),
            "open_price": str(p.price_open),
            "current_price": str(p.price_current),
            "sl": str(p.sl),
            "tp": str(p.tp),
            "profit": str(p.profit),
            "time": p.time
        })

    return jsonify({"status": "success", "positions": result})


@app.route('/order', methods=['POST'])
def place_order():
    connected, msg = _check_mt5_init()
    if not connected:
        return jsonify({"status": "error", "message": msg}), 500

    data = request.json or {}
    symbol = data.get('symbol')
    order_type_str = str(data.get('type', 'BUY')).upper()
    volume = float(data.get('volume', 0.01))
    sl = float(data.get('sl', 0.0)) if data.get('sl') else 0.0
    tp = float(data.get('tp', 0.0)) if data.get('tp') else 0.0

    if not symbol:
        return jsonify({"status": "error", "message": "Symbol is required."}), 400

    symbol_info = mt5.symbol_info(symbol)
    if symbol_info is None:
        return jsonify({"status": "error", "message": f"Symbol '{symbol}' not found in MT5."}), 400

    if not symbol_info.visible:
        if not mt5.symbol_select(symbol, True):
            return jsonify({"status": "error", "message": f"Failed to select symbol '{symbol}'."}), 400

    tick = mt5.symbol_info_tick(symbol)
    if tick is None:
        return jsonify({"status": "error", "message": f"Failed to get current tick for '{symbol}'."}), 400

    order_type = mt5.ORDER_TYPE_BUY if order_type_str == 'BUY' else mt5.ORDER_TYPE_SELL
    price = tick.ask if order_type_str == 'BUY' else tick.bid

    request_dict = {
        "action": mt5.TRADE_ACTION_DEAL,
        "symbol": symbol,
        "volume": volume,
        "type": order_type,
        "price": price,
        "sl": sl,
        "tp": tp,
        "deviation": 20,
        "magic": 234000,
        "comment": "AURA Risk-First Execution",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(request_dict)
    if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
        comment = result.comment if result else mt5.last_error()
        return jsonify({"status": "error", "message": f"Order failed: {comment}"}), 400

    return jsonify({
        "status": "success",
        "order_id": str(result.order),
        "executed_price": str(result.price),
        "volume": str(result.volume),
        "message": "Order executed successfully in MT5."
    })


@app.route('/close_position', methods=['POST'])
def close_position():
    connected, msg = _check_mt5_init()
    if not connected:
        return jsonify({"status": "error", "message": msg}), 500

    data = request.json or {}
    ticket = data.get('ticket')
    if not ticket:
        return jsonify({"status": "error", "message": "Ticket is required."}), 400

    positions = mt5.positions_get(ticket=int(ticket))
    if not positions:
        return jsonify({"status": "error", "message": f"Position ticket {ticket} not found."}), 400

    p = positions[0]
    symbol = p.symbol
    order_type = mt5.ORDER_TYPE_SELL if p.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY
    tick = mt5.symbol_info_tick(symbol)
    price = tick.bid if p.type == mt5.ORDER_TYPE_BUY else tick.ask

    request_dict = {
        "action": mt5.TRADE_ACTION_DEAL,
        "position": p.ticket,
        "symbol": symbol,
        "volume": p.volume,
        "type": order_type,
        "price": price,
        "deviation": 20,
        "magic": 234000,
        "comment": "AURA Close Execution",
        "type_time": mt5.ORDER_TIME_GTC,
        "type_filling": mt5.ORDER_FILLING_IOC,
    }

    result = mt5.order_send(request_dict)
    if result is None or result.retcode != mt5.TRADE_RETCODE_DONE:
        comment = result.comment if result else mt5.last_error()
        return jsonify({"status": "error", "message": f"Close position failed: {comment}"}), 400

    return jsonify({
        "status": "success",
        "ticket": str(p.ticket),
        "close_price": str(result.price),
        "message": f"Position #{ticket} closed successfully."
    })


@app.route('/shutdown', methods=['POST', 'GET'])
def shutdown():
    func = request.environ.get('werkzeug.server.shutdown')
    if func is not None:
        func()
        return jsonify({"status": "shutdown", "message": "MT5 Bridge Service stopping..."})
    else:
        import os, signal
        os.kill(os.getpid(), signal.SIGTERM)
        return jsonify({"status": "shutdown", "message": "MT5 Bridge Service process terminated."})


if __name__ == '__main__':
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass
    print("=" * 60)
    print("[MT5 Bridge] AURA MT5 Local Bridge Service starting on http://127.0.0.1:8088")
    print("=" * 60)
    app.run(host='127.0.0.1', port=8088, debug=False)

