import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';

export default async function logout(req: express.Request, res: express.Response) {
    try {
        let session = await SuperTokens.getSession(req, res, true);
        await session.revokeSession();
        res.send("");
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
}
