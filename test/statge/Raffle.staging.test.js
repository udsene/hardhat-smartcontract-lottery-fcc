const { developmentChains, networkConfig } = require("../../helper-hardhat-config")
const { deployments, getNamedAccounts, ethers, network } = require("hardhat")
const { assert, expect } = require("chai")

developmentChains.includes(network.name)
    ? describe.skip
    : describe("Raffle Staging Tests", function () {
          let raffle, raffleEntranceFee
          let deployer, accounts

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              raffle = await ethers.getContract("Raffle", deployer)
              raffleEntranceFee = await raffle.getEntranceFee()
              accounts = await ethers.getSigners()
          })

          describe("fulfillRandomWords", function () {
              it("works with live Chainlink keepers and Chainlink VRF, we get a random winner", async function () {
                  // enter the raffle
                  const startingTimeStamp = await raffle.getLastTimeStamp()

                  await new Promise(async (reject, resolve) => {
                      // setup listner before we enter the raffle
                      // just in case the blockchain moves really fast
                      raffle.once("WinnerPicked", async () => {
                          console.log("WinnerPicked Event Fired !")
                          try {
                              const recentWinner = await raffle.getRecentWinner()
                              const raffleState = await raffle.getRaffleState()
                              const winnerEndingBalance = await accounts[0].getBalance()
                              const EndingTimeStamp = await raffle.getLastTimeStamp()

                              await expect(raffle.getPlayer(0)).to.be.reverted
                              assert.equal(recentWinner.toString(), accounts[0].address)
                              assert.equal(raffleState.toString, "0")
                              assert.equal(
                                  winnerEndingBalance.toString(),
                                  winnerStartingBalance.add(raffleEntranceFee).toString()
                              )
                              assert(EndingTimeStamp > startingTimeStamp)
                              resolve()
                          } catch (error) {
                              reject(error)
                              console.log(error)
                          }
                      })
                      // Then entering the raffle
                      await raffle.enterRaffle({ value: raffleEntranceFee })
                      const winnerStartingBalance = await accounts[0].getBalance()
                      // and this code Won't complete until our listner has finished listening
                  })
                  // await raffle.enterRaffle({value: raffleEntranceFee})
              })
          })
      })
