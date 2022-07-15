(async function() {

	const exec = require('@actions/exec');
	await exec.exec('post.sh', []);

})()
