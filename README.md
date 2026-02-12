## About

This includes contracts showing how the [MacroForwarder](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol) can be used.

A _User Macro_ is a contract which implements a specific use case, to be used with the MacroForwarder contract.
[IUserDefinedMacro](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/interfaces/utils/IUserDefinedMacro.sol) only requires one method: `buildBatchOperations`.
A minimal User Macro contract doesn't need to implement more, and can leave the parameter encoding to an offchain component, as shown in [this JS App](https://github.com/d10r/sf-macro-forwarder-demo/blob/master/app.js).
In this repo there's User Macro contracts providing more functionality:
