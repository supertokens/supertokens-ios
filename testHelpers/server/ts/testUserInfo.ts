import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';
import Config from "supertokens-node-mysql-ref-jwt/lib/build/config";
import {getAntiCsrfTokenFromHeaders, getAccessTokenFromCookie, setCookie, getIdRefreshTokenFromCookie} from "supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders";
import * as SessionFunctions from "supertokens-node-mysql-ref-jwt/lib/build/session";
import { AuthError, generateError } from "supertokens-node-mysql-ref-jwt/lib/build/error";
import { clearSessionFromCookie, attachAccessTokenToCookie } from './utils';

export default async function testUserInfo(req: express.Request, res: express.Response) {
    try {
        let session = await getSession(req, res, true);
        let userId = session.getUserId();
        let metaInfo = await session.getSessionData();
        let name = metaInfo.name;

        res.send(JSON.stringify({
            name, userId
        }));
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 

export async function getSession(
    req: express.Request,
    res: express.Response,
    enableCsrfProtection: boolean
): Promise<SuperTokens.Session> {
    let idRefreshToken = getIdRefreshTokenFromCookie(req);
    if (idRefreshToken === undefined) {
        // This means refresh token is not going to be there either, so the session does not exist.
        clearSessionFromCookie(res);
        throw generateError(AuthError.UNAUTHORISED, new Error("missing auth tokens in cookies"));
    }

    let accessToken = getAccessTokenFromCookie(req);
    if (accessToken === undefined) {
        // maybe the access token has expired.
        throw generateError(AuthError.TRY_REFRESH_TOKEN, new Error("access token missing in cookies"));
    }

    try {
        if (typeof enableCsrfProtection !== "boolean") {
            throw generateError(AuthError.GENERAL_ERROR, Error("you need to pass enableCsrfProtection boolean"));
        }
        let config = Config.get();
        enableCsrfProtection = enableCsrfProtection && config.tokens.enableAntiCsrf;
        let antiCsrfToken = enableCsrfProtection ? getAntiCsrfTokenFromHeaders(req) : undefined;
        if (enableCsrfProtection && antiCsrfToken === undefined) {
            throw generateError(AuthError.TRY_REFRESH_TOKEN, Error("anti-csrf token not found in headers"));
        }
        let response = await SessionFunctions.getSession(
            accessToken,
            antiCsrfToken === undefined ? null : antiCsrfToken
        );
        if (response.newAccessToken !== undefined) {
            attachAccessTokenToCookie(res, response.newAccessToken.value, response.newAccessToken.expires);
        }
        return new SuperTokens.Session(response.session.handle, response.session.userId, response.session.jwtPayload, res);
    } catch (err) {
        if (AuthError.isErrorFromAuth(err) && err.errType === AuthError.UNAUTHORISED) {
            clearSessionFromCookie(res);
        }
        throw err;
    }
}