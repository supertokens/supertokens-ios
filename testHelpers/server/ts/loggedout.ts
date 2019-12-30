import * as express from 'express';
import * as SuperTokens from 'supertokens-node';

export default async function loggedout(req: express.Request, res: express.Response) {
    try {
        let sdkName = req.headers["supertokens-sdk-name"];
        let sdkVersion = req.headers["supertokens-sdk-version"];
        res.send(JSON.stringify({
            sdkName, sdkVersion
        }));
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 