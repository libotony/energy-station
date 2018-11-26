'use strict';

export const AssertFail = async function (asyncFn: Function) {
    try {
        await asyncFn
        throw new Error('Expected revert not received')
    } catch (e) {
        const RevertRegex = new RegExp(/Transaction:[\s\S]*exited\ with\ an\ error\ \(status\ 0\)\ after\ consuming\ all\ gas/)
        expect(RevertRegex.test(e.message)).to.be.equal(true, `Expected "status 0(revert)", got ${e.message} instead`)
    }
}