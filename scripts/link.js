var exec = require('child_process').exec
function puts(error, stdout, stderr) { console.log(stdout) }
exec('ln -s Versions/Current/Headers src/ios/libs/Stripe.framework/Headers', puts)
exec('ln -s Versions/Current/Modules src/ios/libs/Stripe.framework/Modules', puts)
exec('ln -s Versions/Current/Stripe src/ios/libs/Stripe.framework/Stripe', puts)
