'use strict'
const EnergyStation = artifacts.require("EnergyStation");
import {AssertFail} from './utils'

let instance

contract('MasterOwned', (accounts) => {

    it('master should be deployer', async () => {
        instance = await EnergyStation.new()
        let owner = await instance.owner.call()
        expect(owner).to.be.equal(accounts[0])
    })

    it('calling a owner-only function without owner should throw error', async () => {
        await AssertFail(instance.withdrawProfit( { from: accounts[1] }))
    })

    it('transfer ownership should success and not write the owner', async () => {
        await instance.transferOwnership(accounts[1], { from: accounts[0] })
        let owner = await instance.owner.call()
        expect(owner).to.be.equal(accounts[0])
    })

    it('accept ownership should write the new owner', async () => {
        let result = await instance.acceptOwnership({ from: accounts[1] })
        let owner = await instance.owner.call()
        expect(owner).to.be.equal(accounts[1])
        expect(result.logs[0]).to.have.property('event', 'OwnerUpdate')
        expect(result.logs[0].args).to.have.property('_prevOwner', accounts[0])
        expect(result.logs[0].args).to.have.property('_newOwner', accounts[1])
        expect(result.logs[1]).to.have.property('event', '$Master')
        expect(result.logs[1].args).to.have.property('newMaster', accounts[1])
    })

})