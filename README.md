# ccTransactionManager
A bash script script to run withing the nix shell to facilitate the transaction orchestration of CC members
> **Warning**
> This script is not yet complete. Use it at your own risk.

## IMPORTANT REQUIREMENTS                                                                            
- Ensure this script is executed within the nix shell environment of the [Credential Manager](https://github.com/IntersectMBO/credential-manager).                 
- It is crucial to run this script from your credential manager directory.                                 
- Before using this script, verify that you have your CC hot credential UTXO and your payment address UTXO.
- Compatibility is limited to [cardano-cli](https://github.com/IntersectMBO/cardano-cli) version 9.4.1.0 or later.                                         
