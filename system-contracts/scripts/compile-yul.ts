// hardhat import should be the first import in the file
import { Command } from "commander";
import * as fs from "fs";
import type { CompilerPaths } from "./utils";
import { compilerLocation, prepareCompilerPaths, spawn } from "./utils";

const COMPILER_VERSION = "1.3.18";
const IS_COMPILER_PRE_RELEASE = true;

export async function compileYul(paths: CompilerPaths, file: string) {
  // const solcCompilerPath = await getSolcLocation();
  const solcCompilerPath = "/root/.cache/hardhat-nodejs/compilers-v2/zksolc";

  const zksolcLocation = await compilerLocation(COMPILER_VERSION, IS_COMPILER_PRE_RELEASE);
  await spawn(
    `${zksolcLocation} ${paths.absolutePathSources}/${file} --solc ${solcCompilerPath} --optimization 3 --system-mode --yul --bin --overwrite -o ${paths.absolutePathArtifacts}`
  );
}

export async function compileYulFolder(path: string) {
  const paths = prepareCompilerPaths(path);
  const files: string[] = (await fs.promises.readdir(path)).filter((fn) => fn.endsWith(".yul"));
  const promises: Promise<void>[] = [];
  for (const file of files) {
    promises.push(compileYul(paths, `${file}`));
  }
  await Promise.all(promises);
}

async function main() {
  const program = new Command();

  program.version("0.1.0").name("compile yul").description("publish preimages for the L2 contracts");

  program.command("compile-bootloader").action(async () => {
    await compileYulFolder("bootloader/build");
    await compileYulFolder("bootloader/tests");
  });

  program.command("compile-precompiles").action(async () => {
    await compileYulFolder("contracts-preprocessed");
    await compileYulFolder("contracts-preprocessed/precompiles");
    await compileYulFolder("contracts-preprocessed/precompiles/test-contracts");
  });

  await program.parseAsync(process.argv);
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error("Error:", err.message || err);
    process.exit(1);
  });
