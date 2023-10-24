use std::str::FromStr;
use std::{num::NonZeroU64, ops::RangeInclusive};
use async_trait::async_trait;
use derive_new::new;
use hyperlane_core::{
    accumulator::incremental::IncrementalMerkle, ChainCommunicationError, ChainResult, Checkpoint,
    Indexer, LogMeta, MerkleTreeHook, MerkleTreeInsertion, SequenceIndexer, H256
};
use tracing::instrument;
use crate::AptosMailbox;
use crate::utils;
use crate::types::*;

#[async_trait]
impl MerkleTreeHook for AptosMailbox {
    #[instrument(err, ret, skip(self))]
    async fn tree(&self, lag: Option<NonZeroU64>) -> ChainResult<IncrementalMerkle> {
        assert!(
            lag.is_none(),
            "Aptos does not support querying point-in-time"
        );
        let view_response = utils::send_view_request(
          &self.aptos_client,
          self.package_address.to_hex_literal(),
          "mailbox".to_string(),
          "outbox_get_tree".to_string(),
          vec![],
          vec![],
        )
        .await?;
        let view_result =
            serde_json::from_str::<MoveMerkleTree>(&view_response[0].to_string()).unwrap();
        Ok(view_result.into())
    }

    #[instrument(err, ret, skip(self))]
    async fn latest_checkpoint(&self, lag: Option<NonZeroU64>) -> ChainResult<Checkpoint> {
        assert!(
            lag.is_none(),
            "Aptos does not support querying point-in-time"
        );
        let tree = self.tree(lag).await?;

        let root = tree.root();
        let count: u32 = tree
            .count()
            .try_into()
            .map_err(ChainCommunicationError::from_other)?;
        let index = count.checked_sub(1).ok_or_else(|| {
            ChainCommunicationError::from_contract_error_str(
                "Outbox is empty, cannot compute checkpoint",
            )
        })?;

        let checkpoint = Checkpoint {
            merkle_tree_hook_address: H256::from_str(&self.package_address.to_hex()).unwrap(),
            mailbox_domain: self.domain.id(),
            root,
            index,
        };
        Ok(checkpoint)
    }

    #[instrument(err, ret, skip(self))]
    async fn count(&self, _maybe_lag: Option<NonZeroU64>) -> ChainResult<u32> {
        let tree = self.tree(_maybe_lag).await?;
        tree.count()
            .try_into()
            .map_err(ChainCommunicationError::from_other)
    }
}

/// Struct that retrieves event data for a Sealevel merkle tree hook contract
#[derive(Debug, new)]
pub struct AptosMerkleTreeHookIndexer {}

#[async_trait]
impl Indexer<MerkleTreeInsertion> for AptosMerkleTreeHookIndexer {
    async fn fetch_logs(
        &self,
        _range: RangeInclusive<u32>,
    ) -> ChainResult<Vec<(MerkleTreeInsertion, LogMeta)>> {
        Ok(vec![])
    }
    async fn get_finalized_block_number(&self) -> ChainResult<u32> {
        Ok(0)
    }
}
#[async_trait]
impl SequenceIndexer<MerkleTreeInsertion> for AptosMerkleTreeHookIndexer {
    async fn sequence_and_tip(&self) -> ChainResult<(Option<u32>, u32)> {
        Ok((None, 0))
    }
}