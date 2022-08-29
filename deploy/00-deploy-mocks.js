const { ethers } = require("ethers")
const { developmentChains } = require("../helper-hardhat-config.js")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId

    const BASE_FEE = ethers.utils.parseEther("0.25") //0.25 is the premium. It costs 0.25 Link per request
    const GAS_PRICE_LINK = 1e9 // 1000000000 // Link per gas. Calculated value based on the gas price of the chain.

    // Eth price goes up to 1,000,000,000
    // Chain link nodes pay the gas fees to give us randomness & do external execution
    // So the price of request change based on the price of gas

    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Local network detected! Deploying mocks...")
        const Mock = await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            args: args,
            log: true,
        })
        log("Mock Deployed !!!")
        log("---------------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
