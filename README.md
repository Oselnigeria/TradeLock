TradeLock  Smart Contract Escrow System for Forex Trades

TradeLock is a decentralized escrow system built on the Stacks blockchain that enables secure forex trading by locking funds until specific pip targets are reached, with automated settlement based on price movements.

 Features

 Automated Escrow: Funds are locked in smart contracts until trade conditions are met
 Pip Target Tracking: Monitors forex price movements to determine trade outcomes
 Stop Loss Protection: Automatic settlement when stoploss levels are hit
 MultiCurrency Support: Supports various forex currency pairs (EUR/USD, GBP/USD, etc.)
 Secure Settlement: Trustless settlement based on oracle price feeds
 Platform Fees: Configurable platform fees for sustainable operation
 Emergency Controls: Admin functions for exceptional circumstances

 How It Works

1. Deposit Funds: Users deposit STX tokens into their TradeLock balance
2. Create Trade: Specify currency pair, entry price, target price, stoploss, and trade type (LONG/SHORT)
3. Lock Escrow: Trade amount is locked in the smart contract escrow
4. Price Monitoring: Oracle updates track realtime forex prices
5. Automated Settlement: Contract automatically settles when target or stoploss is reached
6. Withdraw Winnings: Winners can withdraw their funds plus profits

 Smart Contract Functions

 User Functions
 deposit(amount)  Deposit STX tokens to user balance
 withdraw(amount)  Withdraw available balance
 createtrade()  Create a new forex trade with escrow
 settletrade(tradeid)  Settle an active trade if conditions are met
 canceltrade(tradeid)  Cancel an active trade (trader only)

 ReadOnly Functions
 gettrade(tradeid)  Get trade details
 getuserbalance(user)  Get user's available balance
 getcurrentprice(currencypair)  Get latest price for currency pair
 istargetreached(tradeid)  Check if trade target is reached
 isstoplosshit(tradeid)  Check if stoploss is triggered

 Oracle Functions (Admin Only)
 updateprice(currencypair, price)  Update forex price feeds
 setplatformfee(rate)  Set platform fee rate
 emergencysettle(tradeid, winner)  Emergency settlement function

 Trade Types

 LONG: Profit when price goes up, loss when price goes down
 SHORT: Profit when price goes down, loss when price goes up

 Error Codes

 u100  Owner only function
 u101  Trade not found
 u102  Unauthorized access
 u103  Invalid amount
 u104  Trade already exists
 u105  Trade already settled
 u106  Invalid target price
 u107  Insufficient funds

 Security Features

 Funds locked in smart contract escrow
 Oraclebased price feeds for accurate settlement
 Stoploss protection to limit downside risk
 Emergency settlement capabilities for exceptional cases
 Platform fee mechanism for sustainability

 Deployment

Deploy using Clarinet:

bash
clarinet check
clarinet test
clarinet deploy testnet


 Testing

Run the test suite:

bash
clarinet test


 License

MIT License  see LICENSE file for details.

 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

 Disclaimer

This is experimental software. Use at your own risk. Forex trading involves substantial risk of loss.
