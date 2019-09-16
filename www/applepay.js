var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');

var executeCallback = function(callback, message) {
    if (typeof callback === 'function') {
        callback(message);
    }
};

var ApplePay = {

    /**
     * Determines if the current device supports Apple Pay and has a supported card installed.
     * @param {Function} [successCallback] - Optional success callback, receives message object.
     * @param {Function} [errorCallback] - Optional error callback, receives message object.
     * @returns {Promise}
     */
    canMakePayments: function(successCallback, errorCallback) {
        return new Promise(function(resolve, reject) {
            exec(function(message) {
                executeCallback(successCallback, message);
                resolve(message);
            }, function(message) {
                executeCallback(errorCallback, message);
                reject(message);
            }, 'ApplePay', 'canMakePayments', []);
        });

    },

    /**
     * Opens the Apple Pay sheet and shows the order information.
     * @param {Object} order - object containing order details required to create a PKPaymentRequest.
     * @param {Function} [successCallback] - Optional success callback, receives message object.
     * @param {Function} [errorCallback] - Optional error callback, receives message object.
     * @returns {Promise}
     */
    makePaymentRequest: function(order, successCallback, errorCallback) {

        return new Promise(function(resolve, reject) {
            exec(function(message) {
                executeCallback(successCallback, message);
                resolve(message);
            }, function(message) {
                executeCallback(errorCallback, message);
                reject(message);
            }, 'ApplePay', 'makePaymentRequest', [order]);
        });

    },

    /**
     * While the Apple Pay sheet is still open, and the callback from the `makePaymentRequest` has completed,
     * this call will pass the status to the sheet and close it if successful.
     * @param {String} status - Indicates Payment Authorization success, failure, or type of error.
     * @param {Function} [successCallback] - Optional success callback, receives message object.
     * @param {Function} [errorCallback] - Optional error callback, receives message object.
     * @returns {Promise}
     */
    completeLastTransaction: function(status, successCallback, errorCallback) {

        return new Promise(function(resolve, reject) {
            exec(function(message) {
                executeCallback(successCallback, message);
                resolve(message);
            }, function(message) {
                executeCallback(errorCallback, message);
                reject(message);
            }, 'ApplePay', 'completeLastTransaction', [status]);
        });

    }

};

module.exports = ApplePay;
