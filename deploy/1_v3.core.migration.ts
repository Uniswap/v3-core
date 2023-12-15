import { Deployer, Reporter } from '@solarity/hardhat-migrate'

import { UniswapV3Factory__factory } from '../typechain';

export = async (deployer: Deployer) => {
  const factory = await deployer.deploy(UniswapV3Factory__factory);

  if (process.env.FACTORY_OWNER) {
    await factory.setOwner(process.env.FACTORY_OWNER)
  }

  Reporter.reportContracts(['UniswapV3Factory', factory.address])
};
