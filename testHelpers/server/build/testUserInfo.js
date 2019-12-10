"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : new P(function (resolve) { resolve(result.value); }).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const SuperTokens = require("supertokens-node-mysql-ref-jwt/express");
const config_1 = require("supertokens-node-mysql-ref-jwt/lib/build/config");
const cookieAndHeaders_1 = require("supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders");
const SessionFunctions = require("supertokens-node-mysql-ref-jwt/lib/build/session");
const error_1 = require("supertokens-node-mysql-ref-jwt/lib/build/error");
const utils_1 = require("./utils");
function testUserInfo(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            let session = yield getSession(req, res, true);
            let userId = session.getUserId();
            let metaInfo = yield session.getSessionData();
            let name = metaInfo.name;
            res.send(JSON.stringify({
                name, userId
            }));
        }
        catch (err) {
            if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
                res.status(440).send("Session expired");
            }
            else {
                throw err;
            }
        }
    });
}
exports.default = testUserInfo;
function getSession(req, res, enableCsrfProtection) {
    return __awaiter(this, void 0, void 0, function* () {
        let idRefreshToken = cookieAndHeaders_1.getIdRefreshTokenFromCookie(req);
        if (idRefreshToken === undefined) {
            // This means refresh token is not going to be there either, so the session does not exist.
            utils_1.clearSessionFromCookie(res);
            throw error_1.generateError(error_1.AuthError.UNAUTHORISED, new Error("missing auth tokens in cookies"));
        }
        let accessToken = cookieAndHeaders_1.getAccessTokenFromCookie(req);
        if (accessToken === undefined) {
            // maybe the access token has expired.
            throw error_1.generateError(error_1.AuthError.TRY_REFRESH_TOKEN, new Error("access token missing in cookies"));
        }
        try {
            if (typeof enableCsrfProtection !== "boolean") {
                throw error_1.generateError(error_1.AuthError.GENERAL_ERROR, Error("you need to pass enableCsrfProtection boolean"));
            }
            let config = config_1.default.get();
            enableCsrfProtection = enableCsrfProtection && config.tokens.enableAntiCsrf;
            let antiCsrfToken = enableCsrfProtection ? cookieAndHeaders_1.getAntiCsrfTokenFromHeaders(req) : undefined;
            if (enableCsrfProtection && antiCsrfToken === undefined) {
                throw error_1.generateError(error_1.AuthError.TRY_REFRESH_TOKEN, Error("anti-csrf token not found in headers"));
            }
            let response = yield SessionFunctions.getSession(accessToken, antiCsrfToken === undefined ? null : antiCsrfToken);
            if (response.newAccessToken !== undefined) {
                utils_1.attachAccessTokenToCookie(res, response.newAccessToken.value, response.newAccessToken.expires);
            }
            return new SuperTokens.Session(response.session.handle, response.session.userId, response.session.jwtPayload, res);
        }
        catch (err) {
            if (error_1.AuthError.isErrorFromAuth(err) && err.errType === error_1.AuthError.UNAUTHORISED) {
                utils_1.clearSessionFromCookie(res);
            }
            throw err;
        }
    });
}
exports.getSession = getSession;
//# sourceMappingURL=testUserInfo.js.map