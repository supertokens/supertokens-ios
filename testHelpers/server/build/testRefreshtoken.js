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
const SessionFunctions = require("supertokens-node-mysql-ref-jwt/lib/build/session");
const error_1 = require("supertokens-node-mysql-ref-jwt/lib/build/error");
const cookieAndHeaders_1 = require("supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders");
const utils_1 = require("./utils");
const cookieAndHeaders_2 = require("supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders");
const refreshTokenCounter_1 = require("./refreshTokenCounter");
function testRefreshtoken(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            yield refreshSession(req, res);
            refreshTokenCounter_1.default.incrementRefreshTokenCount();
            res.send("");
        }
        catch (err) {
            if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
                if (err.errType === SuperTokens.Error.UNAUTHORISED_AND_TOKEN_THEFT_DETECTED) {
                    SuperTokens.revokeSessionUsingSessionHandle(err.err.sessionHandle);
                }
                res.status(440).send("Session expired");
            }
            else {
                throw err;
            }
        }
    });
}
exports.default = testRefreshtoken;
function refreshSession(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        let refreshToken = cookieAndHeaders_1.getRefreshTokenFromCookie(req);
        let idRefreshToken = cookieAndHeaders_1.getIdRefreshTokenFromCookie(req);
        if (refreshToken === undefined || idRefreshToken === undefined) {
            utils_1.clearSessionFromCookie(res);
            throw error_1.generateError(error_1.AuthError.UNAUTHORISED, new Error("missing auth tokens in cookies"));
        }
        try {
            let response = yield SessionFunctions.refreshSession(refreshToken);
            utils_1.attachAccessTokenToCookie(res, response.newAccessToken.value, response.newAccessToken.expires);
            utils_1.attachRefreshTokenToCookie(res, response.newRefreshToken.value, response.newRefreshToken.expires);
            utils_1.attachIdRefreshTokenToCookie(res, response.newIdRefreshToken.value, response.newIdRefreshToken.expires);
            cookieAndHeaders_2.setAntiCsrfTokenInHeadersIfRequired(res, response.newAntiCsrfToken);
        }
        catch (err) {
            if (error_1.AuthError.isErrorFromAuth(err) &&
                (err.errType === error_1.AuthError.UNAUTHORISED || err.errType === error_1.AuthError.UNAUTHORISED_AND_TOKEN_THEFT_DETECTED)) {
                utils_1.clearSessionFromCookie(res);
            }
            throw err;
        }
    });
}
//# sourceMappingURL=testRefreshtoken.js.map