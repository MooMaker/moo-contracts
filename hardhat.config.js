require("@nomicfoundation/hardhat-toolbox");
const dotenv = require("dotenv");
dotenv.config({path: __dirname + '/.env'});

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    goerli: {
      url: "https://goerli.infura.io/v3/" + process.env.INFURA_ID,
      accounts: [process.env.DEPLOYER_PK]
    }
  }
};
