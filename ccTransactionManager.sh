#!/bin/bash

############################################################################################################
# IMPORTANT REQUIREMENTS:                                                                                  #
# Ensure this script is executed within the nix shell environment of the orchestrator-cli.                 #
# It is crucial to run this script from your credential manager directory.                                 #
# Before using this script, verify that you have your CC hot credential UTXO and your payment address UTXO.#
# Compatibility is limited to cardano-cli version 9.4.1.0 or later.                                        #
# It is essential to modify these variables and ensure the script is executable.                           #
############################################################################################################

TRANSACTION_FEE=1000000     # Set the transaction fee in Lovelace that you are willing to pay, ensuring it's not too low.
RETURN_ADDRESS="addr"   # Specify the change address for your transaction.

################################################################################
# Do not change anything below this line                                       #
################################################################################

# Variables that cannot be changed
WIDTH=$(tput cols)
PAD=$(("$(("$WIDTH" - 90))" / 2))
if [ "$PAD" -gt 11 ]; then
PADDING=$(printf "%9s" "")
else
PADDING=""
fi

# Colors
#BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
#BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
#BRIGHTBLACK='\033[0;30;1m'
#BRIGHTRED='\033[0;31;1m'
#BRIGHTGREEN='\033[0;32;1m'
#BRIGHTYELLOW='\033[0;33;1m'
#BRIGHTBLUE='\033[0;34;1m'
#BRIGHTMAGENTA='\033[0;35;1m'
#BRIGHTCYAN='\033[0;36;1m'
BRIGHTWHITE='\033[0;37;1m'
NC='\033[0m'

# Voter Hashes Management
declare -A VOTERHASHES

# Check if the main variables have been modified.
if [ "$RETURN_ADDRESS" == "changeMe" ]; then
  echo -e "${RED}Please ensure you have modified the RETURN_ADDRESS variable before running this script.${NC}"
  exit 1
fi

# Function to save voter hashes to a configuration file
save_voterhashes() {
  for key in "${!VOTERHASHES[@]}"; do
    echo "--required-signer-hash ${VOTERHASHES[$key]}" >> voterhashes.conf
  done
}

# Load the voterhashes.conf file if it exists, otherwise prompt the user to create it.
voterhash_verif() {
  if [ -f "voterhashes.conf" ]; then
    echo -e "${GREEN}Do you want to keep the default required signers for your transaction(s)? (yes/no)${NC}"
    read SAME_SIGNERS
      if [ "$SAME_SIGNERS" == "no" ]; then
        rm voterhashes.conf > /dev/null 2>&1
        echo -e "${YELLOW}Enter the number of voter verification key hashes to configure as required signers.${NC}"
        read NUM_VOTERS

        for ((i=1; i<=NUM_VOTERS; i++)); do
          echo -e "${MAGENTA}Enter VOTERHASH$i:${NC}"
          read CREATE_HASH
          VOTERHASHES["VOTERHASH$i"]=$CREATE_HASH
        done

        save_voterhashes
      else
        echo -e "${RED}Invalid input. Please answer 'yes' or 'no'.${NC}"
        exit 1
      fi
  else
    echo -e "${CYAN}voterhashes.conf not found. Enter the number of voter verification key hashes to configure as required signers.${NC}"
    read NUM_VOTERS

    for ((i=1; i<=NUM_VOTERS; i++)); do
      echo -e "${WHITE}Enter VOTERHASH$i:${NC}"
      read CREATE_HASH
      VOTERHASHES["VOTERHASH$i"]=$CREATE_HASH
    done

    save_voterhashes
  fi
}

# Create the vote file(s)
vote_file_creation() {
    echo -e "${GREEN}How many governance actions would you like to vote on?${NC}"
    read NUM_ACTIONS

    for ((i=1; i<=NUM_ACTIONS; i++)); do
        echo -e "${CYAN}What is the governance action ID for action $i?${NC}"
        read GOV_ID
        while true; do
            echo -e "${YELLOW}What is your vote for action $i? (yes, no, abstain)${NC}"
            read VOTE
            if [[ "$VOTE" == "yes" || "$VOTE" == "no" || "$VOTE" == "abstain" ]]; then
                break
            else
                echo -e "${RED}Invalid vote option.${NC}"
            fi
        done
        echo -e "${MAGENTA}What is your anchor URL for action $i?${NC}"
        read METADATA_URL
        echo -e "${WHITE}What is the hash of your anchor file for action $i?${NC}"
        read METADATA_HASH

        orchestrator-cli vote \
          --utxo-file hot-nft.utxo \
          --hot-credential-script-file init-hot/credential.plutus \
          --governance-action-tx-id "${GOV_ID}" \
          --governance-action-index 0 \
          --${VOTE} \
          --metadata-url ${METADATA_URL} \
          --metadata-hash ${METADATA_HASH} \
          --out-dir vote$i
    done
}

transaction_build_raw() {
    # Transaction prompts
        echo -e "${GREEN}What is the payment UTXO you want to spend for your transaction?${NC}"
        read PAYMENT_UTXO
        echo -e "${YELLOW}What is the amount of LOVELACE in that UTXO?${NC}"
        read ORCHESTRATOR_STARTING_BALANCE
        echo -e "${CYAN}Which UTXO do you want to use as collateral to run your script?${NC}"
        read COLLATERAL_UTXO
        echo -e "${MAGENTA}What is your NFT.addr UTXO?${NC}"
        read HOT_NFT_UTXO
        
    # Transaction Variables
    ORCHESTRATOR_ENDING_BALANCE=$(($ORCHESTRATOR_STARTING_BALANCE - $TRANSACTION_FEE))

    # Create transaction body file
    cardano-cli conway transaction build-raw \
      --tx-in "${PAYMENT_UTXO}" \
      --tx-in-collateral "${COLLATERAL_UTXO}" \
      --tx-in ${HOT_NFT_UTXO} \
      --tx-in-script-file init-hot/nft.plutus \
      --tx-in-inline-datum-present \
      --tx-in-redeemer-file vote1/redeemer.json \
      --tx-in-execution-units "(3000000000, 4000000)" \
      --tx-out "$(cat vote1/value)" \
      --tx-out-inline-datum-file vote1/datum.json \
      --tx-out "${RETURN_ADDRESS}+${ORCHESTRATOR_ENDING_BALANCE}" \
      --fee ${TRANSACTION_FEE} \
      --protocol-params-file pparams.json \
      $(cat voterhashes.conf) \
      $(for i in $(seq 1 $NUM_ACTIONS); do echo "--vote-file vote$i/vote "; done) \
      --vote-script-file init-hot/credential.plutus \
      --vote-redeemer-value {} \
      --vote-execution-units "(6000000000,4000000)" \
      --out-file body.json
}

# Print a pretty image of Grace!
generate_image() {
  WIDTH=$(tput cols)
  if [ "$WIDTH" -gt 89 ]; then
echo -e "${CYAN}
${PADDING}                               .^!J5GB#&&&@@@@&&&&#BPY7~:.
${PADDING}                          .^?G#@@@@@@@@@@@@@@@@@@@@@@@@@@@@&BY!.
${PADDING}                      .!P&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&BJ:
${PADDING}                   :J#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&G~
${PADDING}                .J&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@G~
${PADDING}              ~B@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&J.
${PADDING}            !&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@5.
${PADDING}          ~&@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&#####&&@@@@@@@@@@@@@@@@@@@@@Y
${PADDING}        .G@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&BY!:.           .^7P&@@@@@@@@@@@@@@@@@!
${PADDING}       !@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&G!.                      .J&@@@@@@@@@@@@@@@G
${PADDING}      5@@@@@@@@@@@@@@@@@@@@@@@@@@@@@P^                             !&@@@@@@@@@@@@@@&:
${PADDING}     B@@@@@@@@@@@@@@@@@@@@@@@@@@@&7                                  G@@@@@@@@@@@@@@@^
${PADDING}    B@@@@@@@@@@@@@@@@@@@@@@@@@@&!                  ${WHITE}.${CYAN}                  B@@@@@@@@@@@@@@@^
${PADDING}   G@@@@@@@@@@@@@@@@@@@@@@@&&#?                  ${WHITE}7@@@B${CYAN}                .@@@@@@@@@@@@@@@@.
${PADDING}  7@@@@@@@@@@@@@@@@@@#P?^.                       ${WHITE}J@@@&${CYAN}                 &@@@@@@@@@@@@@@@&
${PADDING} .@@@@@@@@@@@@@@@&5^                              ${WHITE}.:.${CYAN}                   ^Y&@@@@@@@@@@@@@J
${PADDING} Y@@@@@@@@@@@@@&!                                      ${WHITE}.^!?YY555YYYJJ?7^${CYAN}   ?@@@@@@@@@@@@@
${PADDING} &@@@@@@@@@@@@5                                    ${WHITE}~5&@@@@@@@@@@@@@@@@@@@:${CYAN}  #@@@@@@@@@@@@7
${PADDING}^@@@@@@@@@@@@@Y...                              ${WHITE}.P@@@@@@@@@@@@@@@@@@@&#P~${CYAN}  ^@@@@@@@@@@@@@B
${PADDING}7@@@@@@@@@@@@@@@@@&#Y:                          ${WHITE}^G@@@@@@@@@@@&BY7^.${CYAN}     .~G@@@@@@@@@@@@@@&
${PADDING}J@@@@@@@@@@@@@@@@@@@@@P              ${WHITE}..          :@@@@@@@B?:${CYAN}    .:~?5B&@@@@@@@@@@@@@@@@@@@
${PADDING}J@@@@@@@@@@@@@@@@@@@@@@.             ${WHITE}B.         ^@@@@&5^${CYAN}        #@@@@@@@@@@@@@@@@@@@@@@@@@
${PADDING}!@@@@@@@@@@@@@@@@@@@@@@.            ${WHITE}:@        :G@@@#~${CYAN}           .@@@@@@@@@@@@@@@@@@@@@@@@&
${PADDING}.@@@@@@@@@@@@@@@@@@@@@@.            ${WHITE}:@:     ~B@@@&^${CYAN}  :P7         G@@@@@@@@@@@@@@@@@@@@@@@G
${PADDING} !@@@@@@@@@@@@@@@@@@@@@#              ${WHITE}~@@@@@@@@!${CYAN}  ~@@@@@@@@P^   .@@@@@@@@@@@@@@@@@@@@@@@&
${PADDING}  #@@@@@@@@@@@@@@@@@@@@@!             ${WHITE}~@@@@@@@5${CYAN}  ^@@@@@@@@@@@@##@@@@@@@@@@@@@@@@@@@@@@@@~
${PADDING}  :@@@@@@@@@@@@@@@@@@@@@@.            ${WHITE}.@@@@@@@.${CYAN}  #@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@P
${PADDING}   !@@@@@@@@@@@@@@@@@@@@@&.            ${WHITE}G@@@@@@${CYAN}   @@@@@@@&G555PB&@@@@@@@@@@@@@@@@@@@@@@#
${PADDING}    !@@@@@@@@@@@@@@@@@@@B!             ${WHITE}.@@@@@@.${CYAN}  #@@@B!.        :5@@@@@@@@@@@@@@@@@@@G
${PADDING}      ?#@@@@@@@@@@@@@@P:                ${WHITE}^@@@@@G${CYAN}  :&P:              7&@@@@@@@@@@@@@&P:
${PADDING}        .^75GB####GY~                    ${WHITE}.5B###:${CYAN}                     :?PB####BPJ~.
${PADDING}
${PADDING}          ${WHITE}  ################################################################
${PADDING}            #            Welcome to the CAC offline voter script           #
${PADDING}            ################################################################
${NC}"
else
  if [ "$WIDTH" -gt 63 ]; then
  PADDING=$(printf "%$(($((WIDTH - 63)) / 2))s" "")
  echo -e "${CYAN}
${PADDING}@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@&&#####&&@@@@@@@@@@@@@@@@@@@
${PADDING}@@@@@@@@@@@@@@@@@@@@@@@@@@@@&BY!:.           .^7P&@@@@@@@@@@@@@
${PADDING}@@@@@@@@@@@@@@@@@@@@@@@@&G!.                      .J&@@@@@@@@@@
${PADDING}@@@@@@@@@@@@@@@@@@@@@@P^                             !&@@@@@@@@
${PADDING}@@@@@@@@@@@@@@@@@@@&7                                  G@@@@@@@
${PADDING}@@@@@@@@@@@@@@@@@&!                  ${WHITE}.${CYAN}                  B@@@@@@
${PADDING}@@@@@@@@@@@@@&&#?                  ${WHITE}7@@@B${CYAN}                .@@@@@@
${PADDING}@@@@@@@#P?^.                       ${WHITE}J@@@&${CYAN}                 &@@@@@
${PADDING}@@@&5^                              ${WHITE}.:.${CYAN}                   ^Y&@@
${PADDING}@&!                                      ${WHITE}.^!?YY555YYYJJ?7^${CYAN}   ?@
${PADDING}5                                    ${WHITE}~5&@@@@@@@@@@@@@@@@@@@:${CYAN}  #
${PADDING}Y...                              ${WHITE}.P@@@@@@@@@@@@@@@@@@@&#P~${CYAN}  ^@
${PADDING}@@@@&#Y:                          ${WHITE}^G@@@@@@@@@@@&BY7^.${CYAN}     .~G@@
${PADDING}@@@@@@@@P              ${WHITE}..          :@@@@@@@B?:${CYAN}    .:~?5B&@@@@@@
${PADDING}@@@@@@@@@.             ${WHITE}B.         ^@@@@&5^${CYAN}        #@@@@@@@@@@@@
${PADDING}@@@@@@@@@.            ${WHITE}:@        :G@@@#~${CYAN}           .@@@@@@@@@@@@
${PADDING}@@@@@@@@@.            ${WHITE}:@:     ~B@@@&^${CYAN}  :P7         G@@@@@@@@@@@
${PADDING}@@@@@@@@@#              ${WHITE}~@@@@@@@@!${CYAN}  ~@@@@@@@@P^   .@@@@@@@@@@@@
${PADDING}@@@@@@@@@@!             ${WHITE}~@@@@@@@5${CYAN}  ^@@@@@@@@@@@@##@@@@@@@@@@@@@
${PADDING}@@@@@@@@@@@.            ${WHITE}.@@@@@@@.${CYAN}  #@@@@@@@@@@@@@@@@@@@@@@@@@@@
${PADDING}@@@@@@@@@@@&.            ${WHITE}G@@@@@@${CYAN}   @@@@@@@&G555PB&@@@@@@@@@@@@@
${PADDING}@@@@@@@@@@B!             ${WHITE}.@@@@@@.${CYAN}  #@@@B!.        :5@@@@@@@@@@@
${PADDING}@@@@@@@@P:                ${WHITE}^@@@@@G${CYAN}  :&P:              7&@@@@@@@@
${PADDING}####GY~                    ${WHITE}.5B###:${CYAN}                     :?PB####
${PADDING}
${PADDING}${BRIGHTWHITE}  #############################################################
${PADDING}  #          Welcome to the CAC offline voter script          #
${PADDING}  #############################################################
${NC}"
    else
      echo -e "${BRIGHTWHITE}
######################################################
#       Welcome to the CAC offline voter script      #
######################################################
${NC}"
    fi
  fi
}

main() {
    generate_image
    voterhash_verif
    vote_file_creation
    transaction_build_raw
}
main
