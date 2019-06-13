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

module.exports.ApplePay = ApplePay;


class ApplePayClient {
	constructor(url) {
		this.url = url;
	}

	createAndCapturePaymentIntent(orderId, paymentMethod, intentId, returnUrl, successCallback, errorCallback) {
		const formData = new URLSearchParams();
		
		if (paymentMethod) {
			formData.append("token", paymentMethod);
			formData.append("return_url", returnUrl);
		} else if (intentId) {
			formData.append("intent_id", intentId);
		}
		
		const me = this;

		return new Promise(function(resolve, reject) {
			(async () => {
				try {
					let json = await me.callRequest("put", me.url + "/orders/" + orderId + "/payment", formData);
					executeCallback(successCallback, json);
					resolve(json);
				} catch(error) {
					executeCallback(errorCallback, error);
					reject(error);
				}
			})();
		});
	}

	async callRequest(httpMethod, url, body) {
		let response = await fetch(url, {
			method: httpMethod,
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

module.exports.ApplePayClient = ApplePayClient;
