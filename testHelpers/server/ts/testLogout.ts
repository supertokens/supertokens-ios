import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';
import { clearSessionFromCookie } from './utils';
import { getSession } from './testUserInfo';

export default async function testLogout(req: express.Request, res: express.Response) {
    try {
        let session = await getSession(req, res, true);
        await session.revokeSession();
        clearSessionFromCookie(res);
        res.send("");
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
}
