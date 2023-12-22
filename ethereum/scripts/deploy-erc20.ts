import * as hardhat from "hardhat";
import "@nomiclabs/hardhat-ethers";
import { Command } from "commander";
import { Wallet } from "ethers";
import { parseEther } from "ethers/lib/utils";
import { web3Provider } from "./utils";
import * as fs from "fs";
import * as path from "path";

const DEFAULT_ERC20 = "TestnetERC20Token";

const testConfigPath = path.join(process.env.ZKSYNC_HOME as string, "etc/test_config/constant");
const ethTestConfig = JSON.parse(fs.readFileSync(`${testConfigPath}/eth.json`, { encoding: "utf-8" }));

const provider = web3Provider();

type Token = {
  address: string | null;
  name: string;
  symbol: string;
  decimals: number;
};

type TokenDescription = Token & {
  implementation?: string;
};

async function deployToken(token: TokenDescription, wallet: Wallet): Promise<Token> {
  token.implementation = token.implementation || DEFAULT_ERC20;
  const tokenFactory = await hardhat.ethers.getContractFactory(token.implementation, wallet);
  const args = token.implementation !== "WETH9" ? [token.name, token.symbol, token.decimals] : [];
  const erc20 = await tokenFactory.deploy(...args, { gasLimit: 5000000 });
  await erc20.deployTransaction.wait();

  if (token.implementation !== "WETH9") {
    await erc20.mint(wallet.address, parseEther("30000000000000000"));
    await erc20.approve(process.env.CONTRACTS_DIAMOND_PROXY_ADDR, parseEther("30000000000000000"));

  }
  for (let i = 0; i < 10; ++i) {
    const testWallet = Wallet.fromMnemonic(ethTestConfig.test_mnemonic as string, "m/44'/60'/0'/0/" + i).connect(
      provider
    );
    if (token.implementation !== "WETH9") {
      await erc20.mint(testWallet.address, parseEther("30000000000000000"));
    }
  }

  token.address = erc20.address;
  // Remove the unneeded field
  if (token.implementation) {
    delete token.implementation;
  }

  return token;
}

async function approve(token: TokenDescription, wallet: Wallet, spenderAddress: String): Promise<void> {
  token.implementation = token.implementation || DEFAULT_ERC20;
  const erc20 = (await hardhat.ethers.getContractFactory(token.implementation, wallet)).attach(token.address);
  console.error("WALLET ADDRESS");
  console.error(wallet.address);
  console.error("WALLET PRIVATE KEY");
  console.error(wallet._signingKey().privateKey);
  await erc20.mint(wallet.address, parseEther("300000000000000000000000000"));
  await erc20.approve(spenderAddress, parseEther("300000000000000000000000000"));

  return;
}

async function main() {
  const program = new Command();

  program.version("0.1.0").name("deploy-erc20").description("deploy testnet erc20 token");

  program
    .command("add")
    .option("-n, --token-name <tokenName>")
    .option("-s, --symbol <symbol>")
    .option("-d, --decimals <decimals>")
    .option("-i --implementation <implementation>")
    .description("Adds a new token with a given fields")
    .action(async (cmd) => {
      const token: TokenDescription = {
        address: null,
        name: cmd.tokenName,
        symbol: cmd.symbol,
        decimals: cmd.decimals,
        implementation: cmd.implementation,
      };

      const wallet = cmd.privateKey
        ? new Wallet(cmd.privateKey, provider)
        : Wallet.fromMnemonic(ethTestConfig.mnemonic, "m/44'/60'/0'/0/1").connect(provider);

      console.error("DEPLOYER ADDRESS");
      console.error(wallet.address);
      console.error("DEPLOYER PRIVATE KEY");
      console.error(wallet._signingKey().privateKey);

      console.log(JSON.stringify(await deployToken(token, wallet), null, 2));
    });

  program
    .command("add-multi <tokens_json>")
    .option("--private-key <private-key>")
    .description("Adds a multiple tokens given in JSON format")
    .action(async (tokens_json: string, cmd) => {
      const tokens: Array<TokenDescription> = JSON.parse(tokens_json);
      const result = [];

      const wallet = cmd.privateKey
        ? new Wallet(cmd.privateKey, provider)
        : Wallet.fromMnemonic(ethTestConfig.mnemonic, "m/44'/60'/0'/0/1").connect(provider);

      console.error("DEPLOYER ADDRESS");
      console.error(wallet.address);
      console.error("DEPLOYER PRIVATE KEY");
      console.error(wallet._signingKey().privateKey);

      for (const token of tokens) {
        result.push(await deployToken(token, wallet));
      }
      console.log(JSON.stringify(result, null, 2));
    });

  program
    .command("approve")
    .option("-t, --token-address <tokenAddress>")
    .option("-s, --spender-address <spender>")
    .description("kcyo")
    .action(async (cmd) => {
      const token: TokenDescription = {
        address: cmd.tokenAddress,
        name: null,
        symbol: null,
        decimals: null,
        implementation: null,
      };

      let wallet = cmd.privateKey
        ? new Wallet(cmd.privateKey, provider)
        : Wallet.fromMnemonic(ethTestConfig.mnemonic, "m/44'/60'/0'/0/1").connect(provider);

      console.error("DEPLOYER ADDRESS");
      console.error(wallet.address);
      console.error("DEPLOYER PRIVATE KEY");
      console.error(wallet._signingKey().privateKey);

      console.log(JSON.stringify(await approve(token, wallet, cmd.spenderAddress), null, 2));

      wallet = Wallet.fromMnemonic(ethTestConfig.mnemonic, "m/44'/60'/0'/0/0").connect(provider);

      console.error("DEPLOYER ADDRESS");
      console.error(wallet.address);
      console.error("DEPLOYER PRIVATE KEY");
      console.error(wallet._signingKey().privateKey);

      console.log(JSON.stringify(await approve(token, wallet, cmd.spenderAddress), null, 2));
    });

  await program.parseAsync(process.argv);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message || err);
    process.exit(1);
  });
