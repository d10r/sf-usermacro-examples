## About

This includes contracts showing how the [MacroForwarder](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/utils/MacroForwarder.sol) can be used.

A _User Macro_ is a contract which implements a specific use case, to be used with the MacroForwarder contract.
[IUserDefinedMacro](https://github.com/superfluid-finance/protocol-monorepo/blob/dev/packages/ethereum-contracts/contracts/interfaces/utils/IUserDefinedMacro.sol) only requires one method: `buildBatchOperations`.
A minimal User Macro contract doesn't need to implement more, and can leave the parameter encoding to an offchain component, as shown in [this JS App](https://github.com/d10r/sf-macro-forwarder-demo/blob/master/app.js).
In this repo there's User Macro contracts providing more functionality:

### Convenience encoder

The method `getParams` takes arguments specific to the User Macro and returns them encoded to `bytes`. This returned bytes can be used to invoke `MacroForwarder.runMacro`

### Specialized children

For L2s the tx fees can be considerably reduced by reducing transaction calldata.
In the example use case of deleting flows, this could be achieved by having User Macros specific for popular tokens, such that the token parameter can be omitted from the calldata.
This could be achieved by having a generic User Macro (which works for any token) include factory functionality which allows it to deploy token specific children.
This is showcased by `MultiFlowDeleteMacroWithFactory`.
