module hp_mailbox::mailbox {

  use std::vector::Self;
  use std::signer;
  use aptos_framework::block;
  use aptos_framework::transaction_context;
  use aptos_framework::event;
  use aptos_std::simple_map::{Self, SimpleMap};

  use hp_library::msg_utils;
  use hp_library::utils;
  use hp_library::h256::{Self, H256};
  use hp_library::merkle_tree::{Self, MerkleTree, count};
  use hp_isms::multisig_ism;
  use hp_router::router::{Self, RouterCap};
  use hp_igps::igps;

  //
  // Constants
  //

  const NONE_DOMAIN: u32 = 0;
  const MAX_MESSAGE_BODY_BYTES: u64 = 2 * 1024;

  //
  // Errors
  //

  const ERROR_INVALID_OWNER: u64 = 0;
  const ERROR_MSG_LENGTH_OVERFLOW: u64 = 1;
  const ERROR_VERSION_MISMATCH: u64 = 2;
  const ERROR_DOMAIN_MISMATCH: u64 = 3;
  const ERROR_ALREADY_DELIVERED: u64 = 4;
  const ERROR_VERIFY_FAILED: u64 = 5;

  //
  // Resources
  //

  struct MailBoxState has key, store {
    owner_address: address,
    local_domain: u32,
    tree: MerkleTree,
    // Mapping (message_id => bool)
    delivered: SimpleMap<vector<u8>, bool>
  }

  //
  // Functions
  //

  /// constructor
  fun init_module(account: &signer) {
    let account_address = signer::address_of(account);

    move_to<MailBoxState>(account, MailBoxState {
      owner_address: account_address,
      local_domain: NONE_DOMAIN, // not yet set
      tree: merkle_tree::new(),
      delivered: simple_map::create<vector<u8>, bool>()
    });
  }

  #[event]
  // event resources
  struct DispatchEvent has store, drop {
    message_id: vector<u8>,
    sender: address,
    dest_domain: u32,
    recipient: vector<u8>,
    block_height: u64,
    transaction_hash: vector<u8>,
    message: vector<u8>,
  }

  #[event]
  struct InsertedIntoTree has store, drop {
    message_id: vector<u8>,
    index: u64,
    sender: address,
    block_height: u64,
    transaction_hash: vector<u8>,
  }

  #[event]
  struct ProcessEvent has store, drop {
    message_id: vector<u8>,
    origin_domain: u32,
    sender: vector<u8>,
    recipient: address,
    block_height: u64,
    transaction_hash: vector<u8>,
  }

  #[event]
  struct IsmSetEvent has store, drop {
    message_id: vector<u8>,
    origin_domain: u32,
    sender: address,
    recipient: address,
  }

  // Entry Functions
  /// Initialize state of Mailbox
  public entry fun initialize(
    account: &signer,
    domain: u32,
  ) acquires MailBoxState {
    assert_owner_address(signer::address_of(account));

    let state = borrow_global_mut<MailBoxState>(@hp_mailbox);

    state.local_domain = domain;
  }

  /**
   * @notice Dispatches a message to an enrolled router via the provided Mailbox.
   */
  public fun dispatch<T>(
    dest_domain: u32,
    message_body: vector<u8>,
    _cap: &RouterCap<T>
  ): vector<u8> acquires MailBoxState {
    let recipient: vector<u8> = router::must_have_remote_router<T>(dest_domain);
    outbox_dispatch(
      router::type_address<T>(),
      dest_domain,
      h256::from_bytes(&recipient),
      message_body
    )
  }

  /**
   * @notice Dispatches a message to an enrolled router via the local router's Mailbox
   * and pays for it to be relayed to the destination.
   */
  public fun dispatch_with_gas<T>(
    account: &signer,
    dest_domain: u32,
    message_body: vector<u8>,
    gas_amount: u256,
    cap: &RouterCap<T>
  ) acquires MailBoxState {
    let message_id = dispatch<T>(dest_domain, message_body, cap);
    igps::pay_for_gas(
      account,
      message_id,
      dest_domain,
      gas_amount
    );
  }

  /**
   * @notice Handles an incoming message
   */
  public fun handle_message<T>(
    message: vector<u8>,
    metadata: vector<u8>,
    _cap: &RouterCap<T>
  ) acquires MailBoxState {
    // let src_domain = msg_utils::origin_domain(&message);
    // let sender_addr = msg_utils::sender(&message);
    // router::assert_router_should_be_enrolled<T>(src_domain, sender_addr);
    inbox_process(
      message,
      metadata
    );
  }


  /// Attempts to deliver `message` to its recipient. Verifies
  /// `message` via the recipient's ISM using the provided `metadata`.
  ///! `message` should be in a specific format
  fun inbox_process(
    message: vector<u8>,
    metadata: vector<u8>
  ) acquires MailBoxState {
    let state = borrow_global_mut<MailBoxState>(@hp_mailbox);

    assert!(msg_utils::version(&message) == utils::get_version(), ERROR_VERSION_MISMATCH);
    assert!(msg_utils::dest_domain(&message) == state.local_domain, ERROR_DOMAIN_MISMATCH);

    let id = msg_utils::id(&message);
    assert!(!simple_map::contains_key(&state.delivered, &id), ERROR_ALREADY_DELIVERED);

    // mark it as delivered
    simple_map::add(&mut state.delivered, id, true);

    assert!(multisig_ism::verify(&metadata, &message), ERROR_VERIFY_FAILED);

    // emit process event
    event::emit(ProcessEvent {
      message_id: id,
      origin_domain: state.local_domain,
      sender: msg_utils::sender(&message),
      recipient: msg_utils::recipient(&message),
      block_height: block::get_current_block_height(),
      transaction_hash: transaction_context::get_transaction_hash()
    });
  }

  /// Dispatches a message to the destination domain & recipient.
  fun outbox_dispatch(
    sender_address: address,
    destination_domain: u32,
    _recipient: H256, // package::module
    message_body: vector<u8>,
  ): vector<u8> acquires MailBoxState {

    let tree_count = outbox_get_count();

    let state = borrow_global_mut<MailBoxState>(@hp_mailbox);

    assert!(vector::length(&message_body) < MAX_MESSAGE_BODY_BYTES, ERROR_MSG_LENGTH_OVERFLOW);

    // convert H256 to 32-bytes vector
    let recipient = h256::to_bytes(&_recipient);

    //! Emit Event so that the relayer can fetch message content
    // TODO : optimize format_message_into_bytes. id() consumes memory

    let message_bytes = msg_utils::format_message_into_bytes(
      utils::get_version(), // version
      tree_count,   // nonce
      state.local_domain,   // domain
      sender_address,          // sender address
      destination_domain,   // destination domain
      recipient,            // recipient
      message_body
    );

    // extend merkle tree
    let id = msg_utils::id(&message_bytes);
    let count = count(&state.tree);
    merkle_tree::insert(&mut state.tree, id);

    // emit dispatch event
    event::emit(DispatchEvent {
      message_id: id,
      sender: sender_address,
      dest_domain: destination_domain,
      recipient,
      block_height: block::get_current_block_height(),
      transaction_hash: transaction_context::get_transaction_hash(),
      message: message_bytes
    });

    event::emit(InsertedIntoTree {
      message_id: id,
      index: count,
      sender: sender_address,
      block_height: block::get_current_block_height(),
      transaction_hash: transaction_context::get_transaction_hash()
    });
    id
  }

  // Admin Functions

  /// Transfer ownership of MailBox
  public fun transfer_ownership(account: &signer, new_owner_address: address) acquires MailBoxState {
    assert_owner_address(signer::address_of(account));
    let state = borrow_global_mut<MailBoxState>(@hp_mailbox);
    state.owner_address = new_owner_address;
  }


  // Assert Functions
  /// Check owner
  inline fun assert_owner_address(account_address: address) acquires MailBoxState {
    assert!(borrow_global<MailBoxState>(@hp_mailbox).owner_address == account_address, ERROR_INVALID_OWNER);
  }

  #[view]
  public fun get_default_ism(): address {
    @hp_isms
  }

  #[view]
  /// Returns module_name of recipient package
  public fun recipient_module_name(recipient: address): vector<u8> {
    router::fetch_module_name(recipient)
  }

  #[view]
  /// Calculates and returns tree's current root
  public fun outbox_get_root(): vector<u8> acquires MailBoxState {
    let state = borrow_global<MailBoxState>(@hp_mailbox);
    merkle_tree::root(&state.tree)
  }

  #[view]
  /// Calculates and returns tree's current root
  public fun outbox_get_tree(): MerkleTree acquires MailBoxState {
    borrow_global<MailBoxState>(@hp_mailbox).tree
  }

  #[view]
  /// Returns the number of inserted leaves in the tree
  public fun outbox_get_count(): u32 acquires MailBoxState {
    let state = borrow_global<MailBoxState>(@hp_mailbox);
    (merkle_tree::count(&state.tree) as u32)
  }

  #[view]
  /// Returns a checkpoint representing the current merkle tree.
  public fun outbox_latest_checkpoint(): (vector<u8>, u32) acquires MailBoxState {
    let count = outbox_get_count();
    if (count > 1) count = count - 1;
    (outbox_get_root(),  count)
  }

  #[view]
  /// Returns current owner
  public fun owner(): address acquires MailBoxState {
    borrow_global<MailBoxState>(@hp_mailbox).owner_address
  }

  #[view]
  /// Returns current local domain
  public fun local_domain(): u32 acquires MailBoxState {
    borrow_global<MailBoxState>(@hp_mailbox).local_domain
  }

  #[view]
  /// Returns if message is delivered here
  public fun delivered(message_id: vector<u8>): bool acquires MailBoxState {
    let state = borrow_global<MailBoxState>(@hp_mailbox);
    simple_map::contains_key(&state.delivered, &message_id)
  }

  #[test_only]
  public fun init_for_test(account: &signer) {
    init_module(account);
  }
}