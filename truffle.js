'use strict'
require("ts-node/register");

module.exports = {
    networks: {
        development: {
            host: "localhost",
            port: 8545,
            network_id: "*" // Match any network id
        }
    },
    // tweak truffle to find ts test files
    test_file_extension_regexp: /.*\.ts$/,
};