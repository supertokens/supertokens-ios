import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';

export default async function refreshtoken(req: express.Request, res: express.Response) {
    try {
        await SuperTokens.refreshSession(req, res);
        res.send("");
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            if (err.errType === SuperTokens.Error.UNAUTHORISED_AND_TOKEN_THEFT_DETECTED) {
                SuperTokens.revokeSessionUsingSessionHandle(err.err.sessionHandle);
            }
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 