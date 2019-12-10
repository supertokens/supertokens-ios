import * as express from "express";
import {setCookie} from 'supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders';
import Config from "supertokens-node-mysql-ref-jwt/lib/build/config";

const accessTokenCookieKey = "sAccessToken";
const refreshTokenCookieKey = "sRefreshToken";
const idRefreshTokenCookieKey = "sIdRefreshToken";

export function setHeader(res: express.Response, key: string, value: string) {
    try {
        let existingHeaders = res.getHeaders();
        let existingValue = existingHeaders[key.toLowerCase()];
        if (existingValue === undefined) {
            res.header(key, value);
        } else {
            res.header(key, existingValue + ", " + value);
        }
    } catch (err) {
        throw Error("General Error");
    }
}

export function clearSessionFromCookie(res: express.Response) {
    let config = Config.get();
    setCookie(
        res,
        accessTokenCookieKey,
        "",
        config.cookie.domain,
        config.cookie.secure,
        false,
        0,
        config.tokens.accessToken.accessTokenPath
    );
    setCookie(
        res,
        idRefreshTokenCookieKey,
        "",
        config.cookie.domain,
        false,
        false,
        0,
        config.tokens.accessToken.accessTokenPath
    );
    setCookie(
        res,
        refreshTokenCookieKey,
        "",
        config.cookie.domain,
        config.cookie.secure,
        false,
        0,
        config.tokens.refreshToken.renewTokenPath
    );
}

export function attachAccessTokenToCookie(res: express.Response, token: string, expiry: number) {
    let config = Config.get();
    setCookie(
        res,
        accessTokenCookieKey,
        token,
        config.cookie.domain,
        config.cookie.secure,
        false,
        expiry,
        config.tokens.accessToken.accessTokenPath
    );
}

export function attachRefreshTokenToCookie(res: express.Response, token: string, expiry: number) {
    let config = Config.get();
    setCookie(
        res,
        refreshTokenCookieKey,
        token,
        config.cookie.domain,
        config.cookie.secure,
        false,
        expiry,
        config.tokens.refreshToken.renewTokenPath
    );
}

export function attachIdRefreshTokenToCookie(res: express.Response, token: string, expiry: number) {
    let config = Config.get();
    setCookie(
        res,
        idRefreshTokenCookieKey,
        token,
        config.cookie.domain,
        false,
        false,
        expiry,
        config.tokens.accessToken.accessTokenPath
    );
}