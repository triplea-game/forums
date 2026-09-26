'use strict';

// NodeBB creates its own database indices only in `nodebb setup`; neither a
// normal boot nor `nodebb upgrade` checks for them. A database that arrived
// any other way (a restore, or the forum's Mongo-to-Postgres migration) runs
// without them, and every write then full-scans legacy_object. This runs
// NodeBB's own createIndices, which is CREATE INDEX IF NOT EXISTS, so it's a
// no-op once they exist and picks up any index a future NodeBB adds.
//
// Runs from /usr/src/app so that nconf and the database module resolve to the
// same instances NodeBB itself uses.

const nconf = require('nconf');

nconf.argv().env({ separator: '__' });

const prestart = require('./src/prestart');

prestart.setupWinston();
prestart.loadConfig(process.env.CONFIG);

const winston = require('winston');
const db = require('./src/database');

(async () => {
	await db.init();
	try {
		await db.createIndices();
	} finally {
		await db.close();
	}
})().then(
	() => process.exit(0),
	(err) => {
		winston.error(`[ensure-indices] ${err.stack}`);
		process.exit(1);
	},
);
