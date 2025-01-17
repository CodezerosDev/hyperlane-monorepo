use std::sync::Arc;
use std::thread::sleep;
use std::time::Duration;

use ethers::providers::{Http, Provider};
use ethers::types::{H160, H256, U256};
use macro_rules_attribute::apply;

use crate::config::Config;
use crate::ethereum::multicall::{DEPLOYER_ADDRESS, SIGNED_DEPLOY_MULTICALL_TX};
use crate::logging::log;
use crate::program::Program;
use crate::utils::{as_task, AgentHandles, TaskHandle};
use crate::{INFRA_PATH, MONOREPO_ROOT_PATH};

mod multicall;

#[apply(as_task)]
pub fn start_anvil(config: Arc<Config>) -> AgentHandles {
    log!("Installing typescript dependencies...");
    let yarn_path ="/home/codezeros-wcr-001/.nvm/versions/node/v18.12.0/bin/yarn";
    let yarn_monorepo = Program::new(yarn_path).working_dir(MONOREPO_ROOT_PATH);
    yarn_monorepo.clone().cmd("install").run().join();
    if !config.is_ci_env {
        // don't need to clean in the CI
        yarn_monorepo.clone().cmd("clean").run().join();
    }
    yarn_monorepo.clone().cmd("build").run().join();

    if !config.is_ci_env {
        // Kill any existing anvil processes just in case since it seems to have issues getting cleaned up
        Program::new("pkill")
            .raw_arg("-SIGKILL")
            .cmd("anvil")
            .run_ignore_code()
            .join();
    }
    log!("Launching anvil...");
    let anvil_args = Program::new("anvil").flag("silent").filter_logs(|_| false); // for now do not keep any of the anvil logs
    let anvil = anvil_args.spawn("ETH");

    sleep(Duration::from_secs(10));

    let yarn_infra = Program::new(yarn_path).working_dir(INFRA_PATH);

    log!("Deploying hyperlane ism contracts...");
    yarn_infra.clone().cmd("deploy-ism").run().join();

    log!("Deploying hyperlane core contracts...");
    yarn_infra.clone().cmd("deploy-core").run().join();

    log!("Deploying multicall contract...");
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(deploy_multicall());

    anvil
}

pub async fn deploy_multicall() {
    let anvil_rpc_url = "http://127.0.0.1:8545";
    let provider = Provider::<Http>::try_from(anvil_rpc_url)
        .unwrap()
        .interval(Duration::from_millis(50u64));

    // fund the deployer address
    provider
        .request::<(H160, U256), ()>(
            "anvil_setBalance",
            (DEPLOYER_ADDRESS, U256::from(1_000_000_000_000_000_000u64)),
        )
        .await
        .unwrap();

    // deploy multicall
    provider
        .request::<[serde_json::Value; 1], H256>(
            "eth_sendRawTransaction",
            [SIGNED_DEPLOY_MULTICALL_TX.into()],
        )
        .await
        .unwrap();
    log!("Successfully deployed multicall contract...");
}
