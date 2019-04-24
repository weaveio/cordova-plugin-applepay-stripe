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
     * @param {Function} [successCallback] - Optional success callback, recieves message object.
     * @param {Function} [errorCallback] - Optional error callback, recieves message object.
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
     * @param {Function} [successCallback] - Optional success callback, recieves message object.
     * @param {Function} [errorCallback] - Optional error callback, recieves message object.
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
     * Shows custom confirmation screen then opens the Apple Pay sheet and shows the order information.
     * @param {Function} [successCallback] - Optional success callback, recieves message object.
     * @param {Function} [errorCallback] - Optional error callback, recieves message object.
     * @returns {Promise}
     */
    confirmAndMakePaymentRequest: function(order, successCallback, errorCallback) {

        return new Promise(function(resolve, reject) {
            exec(function(message) {
                executeCallback(successCallback, message);
                resolve(message);
            }, function(message) {
                executeCallback(errorCallback, message);
                reject(message);
            }, 'ApplePay', 'confirmAndMakePaymentRequest', [order]);
        });

    },

    /**
     * While the Apple Pay sheet is still open, and the callback from the `makePaymentRequest` has completed,
     * this call will pass the status to the sheet and close it if successfull.
     * @param {Function} [successCallback] - Optional success callback, recieves message object.
     * @param {Function} [errorCallback] - Optional error callback, recieves message object.
     * @returns {Promise}
     */
    completeLastTransaction: function(status, intent, successCallback, errorCallback) {

        return new Promise(function(resolve, reject) {
            exec(function(message) {
                executeCallback(successCallback, message);
                resolve(message);
            }, function(message) {
                executeCallback(errorCallback, message);
                reject(message);
            }, 'ApplePay', 'completeLastTransaction', [status, intent]);
        });

    }

};

// module.exports = ApplePay;


class ApplePayClient {
  constructor(url) {
    this.url = url;
  }

//   createAndCapturePaymentIntent(amount, currency, paymentMethod, returnUrl, successCallback, errorCallback) {
//     const formData = new URLSearchParams();
// 	formData.append("amount", amount);
//     formData.append("currency", currency);
//     formData.append("payment_method", paymentMethod);
// 	formData.append("return_url", returnUrl);
//     
//     return new Promise(function(resolve, reject) {
//             try {
//             	let json = await this.doPost(this.url + "/capture_payment", formData);
//             	executeCallback(successCallback, json);
//             	resolve(json);
//             } catch(error) {
//             	executeCallback(errorCallback, error);
//                 reject(error);
//             }
//         });
//   }

  async doPost(url, body) {
    let response = await fetch(url, {
      method: "post",
      body: body
    });

    if (response.ok) {
      return response.json();
    } else {
      let text = await response.text();
      throw new Error("Request Failed: " + text);
    }
  }
}

// module.exports = ApplePayClient;

module.exports.ApplePay = ApplePay;
module.exports.ApplePayClient = ApplePayClient;
