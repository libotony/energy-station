'use strict'
const EnergyStation = artifacts.require("EnergyStation");
import { AssertFail } from './utils'

let instance

contract('Protoed', (accounts) => {

    it('sponsor should be null address', async () => {
        instance = await EnergyStation.new()
        let sponsor = await instance.currentSponsor.call()
        expect(sponsor).to.be.equal('0x' + Array(40).fill(0).join(''))
    })

    it('setCredit', async () => {
        instance = await EnergyStation.new()
        let result = await instance.setCreditPlan(web3.toWei('100'), web3.toWei('1'))
        expect(result.logs[0]).to.have.property('address', instance.address)
        expect(result.logs[0]).to.have.property('event', '$CreditPlan')
        expect(result.logs[0].args.credit.toString(10)).to.be.equal(web3.toWei('100'))
        expect(result.logs[0].args.recoveryRate.toString(10)).to.be.equal(web3.toWei('1'))
    })

    it('creditPlan', async () => { 
        let [credit, recoveryRate] = await instance.creditPlan.call()
        expect(credit.toString(10)).to.be.equal(web3.toWei('100'))
        expect(recoveryRate.toString(10)).to.be.equal(web3.toWei('1'))
    })

    it('non-user address should not be user', async () => {
        let result = await instance.isUser.call(accounts[0])
        expect(result).to.be.equal(false)
    })

    it('non-master address add user should revert', async () => {
        await AssertFail(instance.addUser(accounts[1], { from: accounts[1] }))
    })

    it('add user', async () => {
        let result = await instance.addUser(accounts[1], { from: accounts[0] })
        let isUser = await instance.isUser.call(accounts[1])
        expect(isUser).to.be.equal(true)
        expect(result.logs[0]).to.have.property('address', instance.address)
        expect(result.logs[0]).to.have.property('event', '$User')
        expect(result.logs[0].args.user).to.be.equal(accounts[1])
        let action = Buffer.from(result.logs[0].args.action.replace('0x', ''), 'hex').toString().replace(/\0/g, '')
        expect(action).to.be.equal('added')
    })

    it('remove user', async () => {
        let result = await instance.removeUser(accounts[1], { from: accounts[0] })
        let isUser = await instance.isUser.call(accounts[1])
        expect(isUser).to.be.equal(false)
        expect(result.logs[0]).to.have.property('address', instance.address)
        expect(result.logs[0]).to.have.property('event', '$User')
        expect(result.logs[0].args.user).to.be.equal(accounts[1])
        let action = Buffer.from(result.logs[0].args.action.replace('0x', ''), 'hex').toString().replace(/\0/g, '')
        expect(action).to.be.equal('removed')
    })

});