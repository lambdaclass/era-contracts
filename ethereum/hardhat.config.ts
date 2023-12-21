import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-solpp";
import "@nomiclabs/hardhat-waffle";
import "hardhat-contract-sizer";
import "hardhat-gas-reporter";
import "hardhat-typechain";
import { TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS } from "hardhat/builtin-tasks/task-names";
import { task } from "hardhat/config";
import "solidity-coverage";
import { getNumberFromEnv } from "./scripts/utils";
import path = require("path");
import * as fs from "fs";

// If no network is specified, use the default config
if (!process.env.CHAIN_ETH_NETWORK) {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  require("dotenv").config();
}

// eslint-disable-next-line @typescript-eslint/no-var-requires
const systemParams = require("../SystemConfig.json");

const PRIORITY_TX_MAX_GAS_LIMIT = getNumberFromEnv("CONTRACTS_PRIORITY_TX_MAX_GAS_LIMIT");
const DEPLOY_L2_BRIDGE_COUNTERPART_GAS_LIMIT = getNumberFromEnv("CONTRACTS_DEPLOY_L2_BRIDGE_COUNTERPART_GAS_LIMIT");

const testConfigPath = path.join(process.env.ZKSYNC_HOME as string, "etc/tokens");
console.error("testConfigPath", testConfigPath);
let testConfigFile = fs.readFileSync(`${testConfigPath}/native_erc20.json`, { encoding: "utf-8" });
console.error("testConfigFile", testConfigFile);

if (testConfigFile === "") {
  testConfigFile = '{ "address": "0x0" }';
}

const nativeERC20Token = JSON.parse(testConfigFile);
console.error("nativeERC20Token", nativeERC20Token);
const L1_NATIVE_TOKEN_ADDRESS = nativeERC20Token.address;

const prodConfig = {
  UPGRADE_NOTICE_PERIOD: 0,
  // PRIORITY_EXPIRATION: 101,
  // NOTE: Should be greater than 0, otherwise zero approvals will be enough to make an instant upgrade!
  SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE: 1,
  PRIORITY_TX_MAX_GAS_LIMIT,
  DEPLOY_L2_BRIDGE_COUNTERPART_GAS_LIMIT,
  DUMMY_VERIFIER: false,
  L1_NATIVE_TOKEN_ADDRESS,
};
const testnetConfig = {
  UPGRADE_NOTICE_PERIOD: 0,
  // PRIORITY_EXPIRATION: 101,
  // NOTE: Should be greater than 0, otherwise zero approvals will be enough to make an instant upgrade!
  SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE: 1,
  PRIORITY_TX_MAX_GAS_LIMIT,
  DEPLOY_L2_BRIDGE_COUNTERPART_GAS_LIMIT,
  DUMMY_VERIFIER: true,
  L1_NATIVE_TOKEN_ADDRESS,
};
const testConfig = {
  UPGRADE_NOTICE_PERIOD: 0,
  PRIORITY_EXPIRATION: 101,
  SECURITY_COUNCIL_APPROVALS_FOR_EMERGENCY_UPGRADE: 2,
  PRIORITY_TX_MAX_GAS_LIMIT,
  DEPLOY_L2_BRIDGE_COUNTERPART_GAS_LIMIT,
  DUMMY_VERIFIER: true,
  L1_NATIVE_TOKEN_ADDRESS,
};
const localConfig = {
  ...prodConfig,
  DUMMY_VERIFIER: true,
};

const contractDefs = {
  sepolia: testnetConfig,
  rinkeby: testnetConfig,
  ropsten: testnetConfig,
  goerli: testnetConfig,
  mainnet: prodConfig,
  test: testConfig,
  localhost: localConfig,
};

export default {
  defaultNetwork: "env",
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 9999999,
      },
      outputSelection: {
        "*": {
          "*": ["storageLayout"],
        },
      },
    },
  },
  contractSizer: {
    runOnCompile: false,
    except: ["dev-contracts", "zksync/upgrade-initializers", "zksync/libraries", "common/libraries"],
  },
  paths: {
    sources: "./contracts",
  },
  solpp: {
    defs: (() => {
      const defs = process.env.CONTRACT_TESTS ? contractDefs.test : contractDefs[process.env.CHAIN_ETH_NETWORK];

      let path = `${process.env.ZKSYNC_HOME}/etc/tokens/native_erc20.json`;
      let rawData = fs.readFileSync(path, "utf8");
      let address = "0x52312AD6f01657413b2eaE9287f6B9ADaD93D5FE";
      try {
        let jsonConfig = JSON.parse(rawData);
        address = jsonConfig.address;
      } catch (_e) {
        address = "0x52312AD6f01657413b2eaE9287f6B9ADaD93D5FE";
      }

      return {
        NATIVE_ERC20_ADDRESS: address,
        ...systemParams,
        ...defs,
      };
    })(),
  },
  networks: {
    env: {
      url: process.env.ETH_CLIENT_WEB3_URL?.split(",")[0],
    },
    hardhat: {
      allowUnlimitedContractSize: false,
      forking: {
        url: "https://eth-goerli.g.alchemy.com/v2/" + process.env.ALCHEMY_KEY,
        enabled: process.env.TEST_CONTRACTS_FORK === "1",
      },
    },
  },
  etherscan: {
    apiKey: process.env.MISC_ETHERSCAN_API_KEY,
  },
  gasReporter: {
    enabled: true,
  },
};

task("solpp", "Preprocess Solidity source files").setAction(async (_, hre) =>
  hre.run(TASK_COMPILE_SOLIDITY_GET_SOURCE_PATHS)
);
