require("@nomicfoundation/hardhat-toolbox");

const dotenv = require("dotenv");
dotenv.config({ path: __dirname + '/.env' });

const infura_api_key = process.env.INFURA_API_KEY;
const private_key = process.env.PRIVATE_KEY;

if (!infura_api_key) {
  throw new Error('Set INFURA_API_KEY in env');
}

if (!private_key) {
  throw new Error('Set PRIVATE_KEY in env');
}


/** @type import('hardhat/config').HardhatUserConfig */

module.exports = {
  solidity: "0.8.18",
  networks: {
    goerli: {
      url: "https://goerli.infura.io/v3/" + infura_api_key,
      accounts: [private_key]
    },
    polygon_mumbai: {
      url: "https://polygon-mumbai.infura.io/v3/" + infura_api_key,
      accounts: [private_key]
    },
    goerli: {
      url: "https://optimism-goerli.infura.io/v3/" + infura_api_key,
      accounts: [private_key]
    }
  }
};
