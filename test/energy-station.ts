'use strict'
const EnergyStation = artifacts.require("EnergyStation");

contract('EnergyStation', (accounts) => {
    it('deploy',async () => {
        let instance = await EnergyStation.new()
        expect(instance).to.have.property('address')
    })
})