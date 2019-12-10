import * as express from 'express';
import * as SuperTokens from 'supertokens-node';

import RefreshTokenCounter from './refreshTokenCounter';

export default async function refreshtoken(req: express.Request, res: express.Response) {
    try {
        await SuperTokens.refreshSession(req, res);
        RefreshTokenCounter.incrementRefreshTokenCount();
        res.send("");
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            if (err.errType === SuperTokens.Error.TOKEN_THEFT_DETECTED) {
                await SuperTokens.revokeSessionUsingSessionHandle(err.err.sessionHandle);
            }
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 