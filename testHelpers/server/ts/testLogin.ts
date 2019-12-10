import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';

import Names from './names';
import {attachAccessTokenToCookie, attachRefreshTokenToCookie, attachIdRefreshTokenToCookie} from './utils';
import {setAntiCsrfTokenInHeadersIfRequired} from 'supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders';
import * as SessionFunctions from 'supertokens-node-mysql-ref-jwt/lib/build/session';

export default async function testLogin(req: express.Request, res: express.Response) {
    let response = await createNewSession(res, getRandomString(), undefined, {
        name: getRandomName()
    });
    res.send("");
}

function getRandomString(): string {
    let chars = "abcdefghijklmnopqrstuvwxyz";
    let res = "";
    for (let i = 0; i < 10; i++) {
        res += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return res;
}

function getRandomName(): string {
    let randomName = Names[Math.floor(Math.random() * Names.length)];
    return randomName.firstName + " " + randomName.lastName;
}

async function createNewSession(
    res: express.Response,
    userId: string | number,
    jwtPayload?: any,
    sessionInfo?: any
): Promise<SuperTokens.Session> {
    let response = await SessionFunctions.createNewSession(userId, jwtPayload, sessionInfo);

    // attach tokens to cookies
    attachAccessTokenToCookie(res, response.accessToken.value, response.accessToken.expires);
    attachRefreshTokenToCookie(res, response.refreshToken.value, response.refreshToken.expires);
    attachIdRefreshTokenToCookie(res, response.idRefreshToken.value, response.idRefreshToken.expires);
    setAntiCsrfTokenInHeadersIfRequired(res, response.antiCsrfToken);

    return new SuperTokens.Session(response.session.handle, response.session.userId, response.session.jwtPayload, res);
}