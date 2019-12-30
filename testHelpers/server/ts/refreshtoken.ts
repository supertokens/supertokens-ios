import * as express from 'express';
import * as SuperTokens from 'supertokens-node';

import RefreshAPIDeviceInfo from './refreshAPIDeviceInfo';
import RefreshTokenCounter from './refreshTokenCounter';

export default async function refreshtoken(req: express.Request, res: express.Response) {
    try {
        let sdkName: any = req.headers["supertokens-sdk-name"];
        let sdkVersion: any = req.headers["supertokens-sdk-version"];
        await SuperTokens.refreshSession(req, res);
        RefreshTokenCounter.incrementRefreshTokenCount();
        RefreshAPIDeviceInfo.set(sdkName, sdkVersion);
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