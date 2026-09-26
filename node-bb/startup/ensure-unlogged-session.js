'use strict';

// NodeBB stores sessions in the 'session' table, and every cookieless page
// render stores a CSRF token in a new one, so a scraper turns each request into
// a session write. UNLOGGED skips the WAL for those writes. The cost: after a
// crash or unclean shutdown Postgres empties the table, logging everyone out.
//
// SET UNLOGGED rewrites the whole table under an exclusive lock, so it runs
// only while the table is still logged, and the lock_timeout gives up (to retry
// next start) rather than stall boot behind a running backup. NodeBB creates
// the table after this runs, so a fresh database picks it up on its second
// start; pg_dump keeps UNLOGGED, so a restore carries it over.
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
		const { rows } = await db.pool.query(
			`SELECT relpersistence FROM pg_class WHERE oid = to_regclass('public.session')`,
		);
		if (rows.length && rows[0].relpersistence === 'p') {
			winston.info('[ensure-unlogged-session] Making the session table UNLOGGED');
			await db.pool.query(`SET lock_timeout = '10s'; ALTER TABLE "session" SET UNLOGGED`);
			winston.info('[ensure-unlogged-session] Making the session table UNLOGGED done!');
		}
	} finally {
		await db.close();
	}
})().then(
	() => process.exit(0),
	(err) => {
		winston.error(`[ensure-unlogged-session] ${err.stack}`);
		process.exit(1);
	},
);
