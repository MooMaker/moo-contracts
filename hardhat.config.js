require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
const dotenv = require("dotenv");
dotenv.config({ path: __dirname + '/.env' });

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.18",
  networks: {
    goerli: {
      url: "https://goerli.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY]
    },
    polygon_mumbai: {
      url: "https://polygon-mumbai.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY]
    },
    goerli: {
      url: "https://optimism-goerli.infura.io/v3/" + process.env.INFURA_API_KEY,
      accounts: [process.env.PRIVATE_KEY]
    }
  }
};
