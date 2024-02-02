#![allow(unused)]

use anyhow::Error;
use async_trait::async_trait;
use solana_sdk::signature::Keypair;
use sui_sdk::rpc_types::SuiObjectDataOptions;
use tracing::info;
use tracing::{instrument, warn};

use crate::{AddressFormatter, ConnectionConf, Signer, SuiHpProvider, SuiRpcClient};
use hyperlane_core::{
    Announcement, ChainCommunicationError, ChainResult, ContractLocator, HyperlaneChain,
    HyperlaneContract, HyperlaneDomain, HyperlaneProvider, SignedType, TxOutcome,
    ValidatorAnnounce, H256, H512, U256,
};

use ::sui_sdk::types::base_types::SuiAddress;
use anyhow::{Context, Result};
use once_cell::sync::Lazy;
use std::str::FromStr;
use url::Url;

/// A reference to a ValidatorAnnounce contract on Sui chain
#[derive(Debug)]
pub struct SuiValidatorAnnounce {
    package_address: SuiAddress,
    sui_client: SuiRpcClient,
    client_url: String,
    signer: Option<Signer>,
    domain: HyperlaneDomain,
}

impl SuiValidatorAnnounce {
    /// Create a new Sui ValidatorAnnounce
    pub async fn new(
        conf: ConnectionConf,
        locator: ContractLocator<'_>,
        signer: Option<Signer>,
    ) -> Result<Self, Error> {
        let sui_client = SuiRpcClient::new(conf.url.to_string()).await?;
        let package_address = SuiAddress::from_bytes(<[u8; 32]>::from(locator.address)).unwrap();
        Ok(Self {
            package_address,
            sui_client,
            client_url: conf.url.to_string().clone(),
            signer,
            domain: locator.domain.clone(),
        })
    }

    /// Returns a ContractCall that processes the provided message.
    /// If the provided tx_gas_limit is None, gas estimation occurs.
    #[allow(unused)]
    async fn announce_contract_call(
        &self,
        announcement: SignedType<Announcement>,
        _tx_gas_limit: Option<U256>,
    ) -> Result<(String, bool)> {
        let serialized_signature: [u8; 65] = announcement.signature.into();

        let payer = self
            .signer
            .as_ref()
            .ok_or_else(|| ChainCommunicationError::SignerUnavailable)?;

        todo!()
    }
}

impl HyperlaneContract for SuiValidatorAnnounce {
    fn address(&self) -> H256 {
        H256(self.package_address.to_bytes())
    }
}

impl HyperlaneChain for SuiValidatorAnnounce {
    fn domain(&self) -> &HyperlaneDomain {
        &self.domain
    }

    fn provider(&self) -> Box<dyn HyperlaneProvider> {
        let sui_provider = tokio::runtime::Runtime::new()
            .expect("Failed to create runtime")
            .block_on(async {
                SuiHpProvider::new(self.domain.clone(), self.client_url.clone()).await
            });
        Box::new(sui_provider)
    }
}

#[async_trait]
impl ValidatorAnnounce for SuiValidatorAnnounce {
    async fn get_announced_storage_locations(
        &self,
        validators: &[H256],
    ) -> ChainResult<Vec<Vec<String>>> {
        let validator_addresses: Vec<SuiAddress> = validators
            .iter()
            .map(|v| SuiAddress::from_bytes(v).expect("Failed to convert to SuiAddress"))
            .collect();
        let mut storage_locations = Vec::new();
        for address in validator_addresses {
            let object_response_result = self
                .sui_client
                .read_api()
                .get_owned_objects(address, None, None, None)
                .await
                .unwrap();
            let object_response = object_response_result
                .data
                .first() // TODO: This may not always be first. Unit test this.
                .expect("No object found");
            if let Some(data) = &object_response.data {
                storage_locations.push(serde_json::from_str(&data.object_id.to_string()).unwrap());
            }
        }
        Ok(storage_locations)
    }

    async fn announce_tokens_needed(
        &self,
        _announcement: SignedType<Announcement>,
    ) -> Option<U256> {
        Some(U256::zero())
    }

    #[instrument(err, ret, skip(self))]
    async fn announce(
        &self,
        announcement: SignedType<Announcement>,
        tx_gas_limit: Option<U256>,
    ) -> ChainResult<TxOutcome> {
        info!(
            "Announcing Sui Validator _announcement ={:?}",
            announcement.clone()
        );

        let (tx_hash, is_success) = self
            .announce_contract_call(announcement, tx_gas_limit)
            .await
            .map_err(|e| {
                warn!("Failed to announce contract call: {:?}", e);
                ChainCommunicationError::SignerUnavailable
            })?;

        Ok(TxOutcome {
            transaction_id: H512::from_str(&tx_hash).unwrap(),
            executed: is_success,
            gas_used: U256::zero(),
            gas_price: U256::zero().try_into()?,
        })
    }
}
