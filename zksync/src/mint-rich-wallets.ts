import { Command } from "commander";
import { Wallet, ethers } from "ethers";
import { L2EthToken__factory } from "../../../etc/system-contracts/typechain-types";

const provider = new ethers.providers.JsonRpcProvider("http://127.0.0.1:3050");

async function main() {
  const program = new Command();

  program.version("0.1.0").name("mint-rich-wallets").description("mint rich wallets");

  program
    .command("mint")
    .option("--wallets <wallets>")
    .action(async (cmd) => {
      let wallet = new Wallet("0xe131bc3f481277a8f73d680d9ba404cc6f959e64296e0914dded403030d4f705", provider);
      const l2_eth_token = L2EthToken__factory.connect("0x000000000000000000000000000000000000800a", wallet);
      for (let i = 0; i < cmd.wallets; ++i) {
        let test_wallet = Wallet.createRandom().connect(provider);
        console.log(`Minting for wallet: ${test_wallet.address}`);
        await l2_eth_token.mint(test_wallet.address, 1000000000000000);
      }
    });

  await program.parseAsync(process.argv);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err);
    process.exit(1);
  });
