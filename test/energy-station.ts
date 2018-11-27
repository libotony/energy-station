'use strict'
const EnergyStation = artifacts.require("EnergyStation");
const Energy = artifacts.require('Energy')
import {BigNumber} from 'bignumber.js'
import { AssertFail } from './utils'

let energyInstance = Energy.at('0x0000000000000000000000000000456E65726779')
let instance

contract('EnergyStation', (accounts) => {

    it('deploy',async () => {
        instance = await EnergyStation.new()
        expect(instance).to.have.property('address')
    })

    it('convert should fail', async () => {
        await AssertFail(instance.convertForEnergy(1, {from: accounts[0], value:web3.toWei('1')}))
    })

    it('initiate energy station', async () => {
        await instance.fillVET({ from: accounts[0], value: web3.toWei('1000000') })
        await energyInstance.approve(instance.address, web3.toWei('10000000'), { from: accounts[0] })
        await instance.fillEnergy(web3.toWei('10000000'), { from: accounts[0] })
        await instance.setConversionFee(5000, { from: accounts[0] })
        await instance.changeConversionStatus(true, { from: accounts[0] })
    })

    it('getVETReturn', async () => {
        let vetBalance = new BigNumber(await instance.vetVirtualBalance.call())
        let energyBalance = new BigNumber(await instance.energyVirtualBalance.call())

        let amount = new BigNumber(web3.toWei('100'))
        let ret = await instance.getVETReturn.call(web3.toWei('100'))
        let calcedRet = vetBalance.multipliedBy(amount).div(energyBalance.plus(amount)).multipliedBy((1000000 - 5000) / 1000000)
        expect(ret.toString(10)).to.be.equal(calcedRet.dp(0).toString(10))
    })

    it('getEnergyReturn', async () => {
        let vetBalance = new BigNumber(await instance.vetVirtualBalance.call())
        let energyBalance = new BigNumber(await instance.energyVirtualBalance.call())

        let amount = new BigNumber(web3.toWei('100'))
        let ret = await instance.getEnergyReturn.call(web3.toWei('100'))
        let calcedRet = energyBalance.multipliedBy(amount).div(vetBalance.plus(amount)).multipliedBy((1000000 - 5000) / 1000000)
        expect(ret.toString(10)).to.be.equal(calcedRet.dp(0).toString(10))
    })

    it('no convert withdrawProfit should revert', async () => {
        AssertFail(instance.withdrawProfit({from: accounts[0]}))
    })

    it('convertForEnergy', async () => {
        let vetBalance = new BigNumber(await instance.vetVirtualBalance.call())
        let energyBalance = new BigNumber(await instance.energyVirtualBalance.call())

        let ret = await instance.convertForEnergy(1, { from: accounts[0], value: web3.toWei('100') })
        let amount = new BigNumber(web3.toWei('100'))
        let calcedRet = energyBalance.multipliedBy(amount).div(vetBalance.plus(amount)).multipliedBy((1000000 - 5000) / 1000000).dp(0)
        let fee = energyBalance.multipliedBy(amount).div(vetBalance.plus(amount)).minus(calcedRet).dp(0)
        expect(ret.logs[0].address).to.be.equal(instance.address)
        expect(ret.logs[0].event).to.be.equal('Conversion')
        expect(ret.logs[0].args.tradeType.toString()).to.be.equal('0')
        expect(ret.logs[0].args._trader).to.be.equal(accounts[0])
        expect(ret.logs[0].args._sellAmount.toString()).to.be.equal(amount.toString())
        expect(ret.logs[0].args._return.toString()).to.be.equal(calcedRet.toString())
        expect(ret.logs[0].args._conversionFee.toString()).to.be.equal(fee.toString())
    })

    it('larger minReturn should revert when convertForEnergy', async () => {
        let minReturn = await instance.getEnergyReturn.call(web3.toWei('100'))
        AssertFail(instance.convertForEnergy(minReturn.plus(1) ,{ from: accounts[0], value: web3.toWei('100') }))
    })

    it('no approve covertForVET should fail', async () => { 
        AssertFail(instance.convertForVET(web3.toWei('100'), 1, { from: accounts[0]}))
    })

    it('covertForVET', async () => {
        let vetBalance = new BigNumber(await instance.vetVirtualBalance.call())
        let energyBalance = new BigNumber(await instance.energyVirtualBalance.call())

        await energyInstance.approve(instance.address, web3.toWei('100'), { from: accounts[0] })
        let ret = await instance.convertForVET(web3.toWei('100'), 1, { from: accounts[0] })
        let amount = new BigNumber(web3.toWei('100'))
        let calcedRet = vetBalance.multipliedBy(amount).div(energyBalance.plus(amount)).multipliedBy((1000000 - 5000) / 1000000).dp(0)
        let fee = vetBalance.multipliedBy(amount).div(energyBalance.plus(amount)).minus(calcedRet).dp(0)

        expect(ret.logs[0].address).to.be.equal(instance.address)
        expect(ret.logs[0].event).to.be.equal('Conversion')
        expect(ret.logs[0].args.tradeType.toString()).to.be.equal('1')
        expect(ret.logs[0].args._trader).to.be.equal(accounts[0])
        expect(ret.logs[0].args._sellAmount.toString()).to.be.equal(amount.toString())
        expect(ret.logs[0].args._return.toString()).to.be.equal(calcedRet.toString())
        expect(ret.logs[0].args._conversionFee.toString()).to.be.equal(fee.toString())
    })

    it('larger minReturn should revert when covertForVET', async () => {
        await energyInstance.approve(instance.address, web3.toWei('100'), { from: accounts[0] })
        let minReturn = await instance.getVETReturn.call(web3.toWei('100'))
        AssertFail(instance.convertForVET(web3.toWei('100'), minReturn.plus(1), { from: accounts[0] }))
    })

    it('withdrawProfit should not revert', async () => {
        await instance.withdrawProfit({ from: accounts[0] })
    })

})