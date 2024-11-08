FUNCTION=$1

LN1_EXAMPLES_ADDRESS="0xd1eaef049ac77e63f2ffefae43e14c1a73700f25cde849b6614dc3f3580123fc"
LN1_IGPS_ADDRESS="0xc5cb1f1ce6951226e9c46ce8d42eda1ac9774a0fef91e2910939119ef0c95568"
LN1_ISMS_ADDRESS="0x6bbae7820a27ff21f28ba5a4b64c8b746cdd95e2b3264a686dd15651ef90a2a1"
LN1_LIBRARY_ADDRESS="0xe818394d0f37cd6accd369cdd4e723c8dc4f9b8d2517264fec3d9e8cabc66541"
LN1_MAILBOX_ADDRESS="0x476307c25c54b76b331a4e3422ae293ada422f5455efed1553cf4de1222a108f"
LN1_ROUTER_ADDRESS="0xafce3ab5dc5d513c13e746cef4d65bf54f4abdcb34ea8ab0728d01c035610e3d"
LN1_VALIDATOR_ANNOUNCE_ADDRESS="0xa4a4eb4bab83650ba62cabe9ce429ad021b29c12f2fbf808768838255c7e191d"

LN2_EXAMPLES_ADDRESS="0xb2586f8d1347b988157b9e7aaea24d19064dfb596835145db1f93ff931948732"
# [178,88,111,141,19,71,185,136,21,123,158,122,174,162,77,25,6,77,251,89,104,53,20,93,177,249,63,249,49,148,135,50]
LN2_IGPS_ADDRESS="0xea7d568d0705450331a8f09fd1c823faec91f4ef1c7e6ed4b12c0c53d0c08bc8"
LN2_ISMS_ADDRESS="0x39a36a558e955f29f60f9e7ad7e391510fcd6a744d8aec9b86952106bfc3e5e2"
LN2_LIBRARY_ADDRESS="0xc29e4ea7972150a5f3bd6531eba94907ce2be3b47eb17eaee40d381d2fd9122c"
LN2_MAILBOX_ADDRESS="0xd338e68ca12527e77cab474ee8ec91ffa4e6512ced9ae8f47e28c5c7c4804b78"
LN2_ROUTER_ADDRESS="0xd85669f567da6d24d296dccb7a7bfa1c666530eeb0e7b294791094e7a2dce8e3"
LN2_VALIDATOR_ANNOUNCE_ADDRESS="0xce1f65297828eaa6e460724a869317154f05cdde26619c0e5c0ca23aac3f69c7"

LN1_VALIDATOR_SIGNER_ADDRESS="0x21779477148b80ec9e123cc087a04ebbfb4a9de0ba64aa8f31510a0266423bb9"
LN1_VALIDATOR_ETH_ADDY="0x04e7bc384e10353c714327f7b85b3d0ceb52bf6d"
LN1_RELAYER_SIGNER_ADDRESS="0x8b4376073a408ece791f4adc34a8afdde405bae071711dcbb95ca4e5d4f26c93"

LN2_VALIDATOR_SIGNER_ADDRESS="0xef7adb55757d157d1a1f76d5d04806aba4f9099a32260b9356d6dd53c177cd1e"
LN2_VALIDATOR_ETH_ADDY="0x8a9f9818b6ba031c5f2c8baf850942d4c98fa2ee"
LN2_RELAYER_SIGNER_ADDRESS="0xcc7867910e0c3a1b8f304255123a4459c0222c78987d628f1effbf122f436b7b"

APTOSDEVNET_DOMAIN=14477
APTOSTESTNET_DOMAIN=14402
APTOSLOCALNET1_DOMAIN=14411
APTOSLOCALNET2_DOMAIN=14412
BSCTESTNET_DOMAIN=97
TEST1_DOMAIN=13371
TEST1_VALIDATOR_ADDR="0x15d34aaf54267db7d7c367839aaf71a00a2c6a65"
TEST1_RECEIPIENT_ADDR="0xf5059a5D33d5853360D16C683c16e67980206f36"
TEST1_DOMAIN_ROUTER_ISM_ADDR="0xb0279Db6a2F1E01fbC8483FCCef0Be2bC6299cC3"
#anvil 0th key
TEST1_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
TEST1_RPC_URL="http://127.0.0.1:8545"
TEST1_GAS_LIMIT=300000
TEST1_MAILBOX="0x9A9f2CCfdE556A7E9Ff0848998Aa4a0CFD8863AE"

REST_API_URL="http://0.0.0.0:8080/v1"
# VALIDATOR_ETH_SIGNER="0x598264ff31f198f6071226b2b7e9ce360163accd"

# inits
function init_ln1_modules() {  
  # To make use of aptos cli
  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"
  # init validator
  cd ../validator-announce && aptos move run --assume-yes --function-id $LN1_VALIDATOR_ANNOUNCE_ADDRESS::validator_announce::initialize --args address:$LN1_MAILBOX_ADDRESS u32:$APTOSLOCALNET1_DOMAIN --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/validator-announce-keypair.json"

  # setting router
  L1_ROUTER_CAP="$LN1_EXAMPLES_ADDRESS::hello_world::HelloWorld"
  # enroll ln2 router
  cd ../router && aptos move run --assume-yes --function-id $LN1_ROUTER_ADDRESS::router::enroll_remote_router --type-args $L1_ROUTER_CAP --args u32:$APTOSLOCALNET2_DOMAIN "u8:[178,88,111,141,19,71,185,136,21,123,158,122,174,162,77,25,6,77,251,89,104,53,20,93,177,249,63,249,49,148,135,50]" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/examples-keypair.json"

  cd ../mailbox && aptos move run --assume-yes --function-id $LN1_MAILBOX_ADDRESS::mailbox::initialize --args u32:$APTOSLOCALNET1_DOMAIN --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/mailbox-keypair.json"
  
  # set ln2 validator to ism
  cd ../isms && aptos move run --assume-yes --function-id $LN1_ISMS_ADDRESS::multisig_ism::set_validators_and_threshold --args 'address:["'$LN2_VALIDATOR_ETH_ADDY'"]' u64:1 u32:$APTOSLOCALNET2_DOMAIN  --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/isms-keypair.json"

  # address bytes of testReceiptant of test1 [245,5,154,93,51,213,133,51,96,209,108,104,60,22,230,121,128,32,111,54]
  # enroll test1 evm to router
  cd ../router && aptos move run --assume-yes --function-id $LN1_ROUTER_ADDRESS::router::enroll_remote_router --type-args $L1_ROUTER_CAP --args u32:$TEST1_DOMAIN "u8:[245,5,154,93,51,213,133,51,96,209,108,104,60,22,230,121,128,32,111,54]" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/examples-keypair.json"

  # set test1 evm to ism
  cd ../isms && aptos move run --assume-yes --function-id $LN1_ISMS_ADDRESS::multisig_ism::set_validators_and_threshold --args 'address:["'$TEST1_VALIDATOR_ADDR'"]' u64:1 u32:$TEST1_DOMAIN  --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/isms-keypair.json"

  # set inter-chain gas oracle for test 1
  cd ../igps && aptos move run --assume-yes --function-id $LN1_IGPS_ADDRESS::gas_oracle::set_remote_gas_data --args u32:$TEST1_DOMAIN u128:265380 u128:1500 --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/igps-keypair.json"
}

function init_ln2_modules() {  
  # To make use of aptos cli
  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"
  # init validator
  cd ../validator-announce && aptos move run --assume-yes --function-id $LN2_VALIDATOR_ANNOUNCE_ADDRESS::validator_announce::initialize --args address:$LN2_MAILBOX_ADDRESS u32:$APTOSLOCALNET2_DOMAIN --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet2/validator-announce-keypair.json"

  # setting router
  L2_ROUTER_CAP="$LN2_EXAMPLES_ADDRESS::hello_world::HelloWorld"
  # enroll ln1 router
  cd ../router && aptos move run --assume-yes --function-id $LN2_ROUTER_ADDRESS::router::enroll_remote_router --type-args $L2_ROUTER_CAP --args u32:$APTOSLOCALNET1_DOMAIN "u8:[209,234,239,4,154,199,126,99,242,255,239,174,67,225,76,26,115,112,15,37,205,232,73,182,97,77,195,243,88,1,35,252]" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet2/examples-keypair.json"

  cd ../mailbox && aptos move run --assume-yes --function-id $LN2_MAILBOX_ADDRESS::mailbox::initialize --args u32:$APTOSLOCALNET2_DOMAIN --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet2/mailbox-keypair.json"
  
  # set ln1 validator to ism
  cd ../isms && aptos move run --assume-yes --function-id $LN2_ISMS_ADDRESS::multisig_ism::set_validators_and_threshold --args 'address:["'$LN1_VALIDATOR_ETH_ADDY'"]' u64:1 u32:$APTOSLOCALNET1_DOMAIN  --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet2/isms-keypair.json"
}

function enroll_remote_router_to_test1() {
  cd "$(pwd)"
  tx_hash_result=$(curl --silent --location --request POST 'http://127.0.0.1:8545' \
  --header 'Content-Type: application/json' \
  --data-raw '{
    "jsonrpc":"2.0",
    "method":"eth_sendTransaction",
    "params":[{
      "from": "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
          "gas": "0x1000000",
          "gasPrice": "0x100000000",
      "value": "0x0",
      "data": "0x60c060405260066080523480156013575f80fd5b506040516102cd3803806102cd8339810160408190526030916037565b60a052604d565b5f602082840312156046575f80fd5b5051919050565b60805160a05161025b6100725f395f81816086015260dc01525f6048015261025b5ff3fe608060405234801561000f575f80fd5b506004361061003f575f3560e01c80636465e69f1461004357806367e404ce14610081578063f7e83aee146100b6575b5f80fd5b61006a7f000000000000000000000000000000000000000000000000000000000000000081565b60405160ff90911681526020015b60405180910390f35b6100a87f000000000000000000000000000000000000000000000000000000000000000081565b604051908152602001610078565b6100c96100c4366004610175565b6100d9565b6040519015158152602001610078565b5f7f0000000000000000000000000000000000000000000000000000000000000000610105848461010f565b1495945050505050565b5f61011e6029600984866101e1565b61012791610208565b90505b92915050565b5f8083601f840112610140575f80fd5b50813567ffffffffffffffff811115610157575f80fd5b60208301915083602082850101111561016e575f80fd5b9250929050565b5f805f8060408587031215610188575f80fd5b843567ffffffffffffffff81111561019e575f80fd5b6101aa87828801610130565b909550935050602085013567ffffffffffffffff8111156101c9575f80fd5b6101d587828801610130565b95989497509550505050565b5f80858511156101ef575f80fd5b838611156101fb575f80fd5b5050820193919092039150565b8035602083101561012a575f19602084900360031b1b169291505056fea26469706673582212200f0a243341c5251a34e7ac92e0a830a66c2378581331a601837fcaf6f5101db964736f6c634300081a0033d1eaef049ac77e63f2ffefae43e14c1a73700f25cde849b6614dc3f3580123fc"
    }],
    "id":1
  }')

  tx_hash=$(echo $tx_hash_result | jq -r ".result")
#  echo $tx_hash

  sleep 2

  contract_addr_result=$(curl --silent --location --request POST 'http://127.0.0.1:8545' \
  --header 'Content-Type: application/json' \
  --data-raw "{
      \"jsonrpc\": \"2.0\",
      \"method\": \"eth_getTransactionReceipt\",
      \"params\": [
          \"$tx_hash\"
      ],
      \"id\": 1
  }")

  contract_addr=$(echo $contract_addr_result | jq -r '.result.contractAddress')
#  echo $contract_addr

  # need to add private key here.
  # after that it should work like a charm
  cast send $TEST1_DOMAIN_ROUTER_ISM_ADDR "set(uint32,address)" "$APTOSLOCALNET1_DOMAIN" "$contract_addr" --rpc-url $TEST1_RPC_URL --private-key $TEST1_PRIVATE_KEY
}

function send_hello_ln1_to_ln2() {
  
  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"

  cd ../examples && aptos move run --function-id $LN1_EXAMPLES_ADDRESS::hello_world::send_message --args u32:$APTOSLOCALNET2_DOMAIN string:"Hello World!" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/examples-keypair.json" --assume-yes
}
function send_hello_ln2_to_ln1() {
  
  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"

  cd ../examples && aptos move run --function-id $LN2_EXAMPLES_ADDRESS::hello_world::send_message --args u32:$APTOSLOCALNET1_DOMAIN string:"Hello World!" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet2/examples-keypair.json" --assume-yes
}

function send_hello_ln1_to_test1() {

  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"

  cd ../examples && aptos move run --function-id $LN1_EXAMPLES_ADDRESS::hello_world::send_message --args u32:$TEST1_DOMAIN string:"Hello World!" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/examples-keypair.json" --assume-yes
  message_id_response=$(cd ../examples && aptos move view --function-id $LN1_EXAMPLES_ADDRESS::hello_world::view_last_id --url $REST_API_URL)
  message_id=$(echo $message_id_response | jq -r '.Result[0]')
  echo "$message_id"
  message_id_bytes=$(cd ../e2e && ./hex_to_bytes $message_id)
  echo "$message_id_bytes"

  cd ../igps && aptos move run --function-id $LN1_IGPS_ADDRESS::igps::pay_for_gas --args "u8:$message_id_bytes" u32:$TEST1_DOMAIN "u256:$TEST1_GAS_LIMIT" --url $REST_API_URL --private-key-file "../e2e/aptos-test-keys/localnet1/examples-keypair.json" --assume-yes
}

function send_hello_test1_to_ln1() {

  export PATH="/root/.local/bin:$PATH"

  cd "$(pwd)"
  fee=$(cast call $TEST1_MAILBOX "quoteDispatch(uint32,bytes32,bytes)(uint256)" "$APTOSLOCALNET1_DOMAIN" "$LN1_EXAMPLES_ADDRESS" "0x48656c6c6f20576f726c6421" --rpc-url $TEST1_RPC_URL --private-key $TEST1_PRIVATE_KEY)
  echo "FEE that quoted: $fee"
  cast send $TEST1_MAILBOX --value $fee "dispatch(uint32,bytes32,bytes)" "$APTOSLOCALNET1_DOMAIN" "$LN1_EXAMPLES_ADDRESS" "0x48656c6c6f20576f726c6421" --rpc-url $TEST1_RPC_URL --private-key $TEST1_PRIVATE_KEY
}

#`address:0x1 bool:true u8:0 u256:1234 "bool:[true, false]" 'address:[["0xace", "0xbee"], []]'`

if [[ $FUNCTION == "" ]]; then
    echo "input function name"
else
    $FUNCTION
fi
