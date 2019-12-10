import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';
import * as SessionFunctions from "supertokens-node-mysql-ref-jwt/lib/build/session";
import { AuthError, generateError } from "supertokens-node-mysql-ref-jwt/lib/build/error";

import {getRefreshTokenFromCookie, getIdRefreshTokenFromCookie} from 'supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders';
import {clearSessionFromCookie, attachAccessTokenToCookie, attachRefreshTokenToCookie, attachIdRefreshTokenToCookie} from './utils';
import {setAntiCsrfTokenInHeadersIfRequired} from 'supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders';
import RefreshTokenCounter from './refreshTokenCounter';

export default async function testRefreshtoken(req: express.Request, res: express.Response) {
    try {
        await refreshSession(req, res);
        RefreshTokenCounter.incrementRefreshTokenCount();
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

async function refreshSession(req: express.Request, res: express.Response) {
    let refreshToken = getRefreshTokenFromCookie(req);
    let idRefreshToken = getIdRefreshTokenFromCookie(req);

    if (refreshToken === undefined || idRefreshToken === undefined) {
        clearSessionFromCookie(res);
        throw generateError(AuthError.UNAUTHORISED, new Error("missing auth tokens in cookies"));
    }

    try {
        let response = await SessionFunctions.refreshSession(refreshToken);
        attachAccessTokenToCookie(res, response.newAccessToken.value, response.newAccessToken.expires);
        attachRefreshTokenToCookie(res, response.newRefreshToken.value, response.newRefreshToken.expires);
        attachIdRefreshTokenToCookie(res, response.newIdRefreshToken.value, response.newIdRefreshToken.expires);
        setAntiCsrfTokenInHeadersIfRequired(res, response.newAntiCsrfToken);
    } catch (err) {
        if (
            AuthError.isErrorFromAuth(err) &&
            (err.errType === AuthError.UNAUTHORISED || err.errType === AuthError.UNAUTHORISED_AND_TOKEN_THEFT_DETECTED)
        ) {
            clearSessionFromCookie(res);
        }
        throw err;
    }
}