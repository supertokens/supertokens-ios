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
const names_1 = require("./names");
const utils_1 = require("./utils");
const cookieAndHeaders_1 = require("supertokens-node-mysql-ref-jwt/lib/build/cookieAndHeaders");
const SessionFunctions = require("supertokens-node-mysql-ref-jwt/lib/build/session");
function testLogin(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        let response = yield createNewSession(res, getRandomString(), undefined, {
            name: getRandomName()
        });
        res.send("");
    });
}
exports.default = testLogin;
function getRandomString() {
    let chars = "abcdefghijklmnopqrstuvwxyz";
    let res = "";
    for (let i = 0; i < 10; i++) {
        res += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return res;
}
function getRandomName() {
    let randomName = names_1.default[Math.floor(Math.random() * names_1.default.length)];
    return randomName.firstName + " " + randomName.lastName;
}
function createNewSession(res, userId, jwtPayload, sessionInfo) {
    return __awaiter(this, void 0, void 0, function* () {
        let response = yield SessionFunctions.createNewSession(userId, jwtPayload, sessionInfo);
        // attach tokens to cookies
        utils_1.attachAccessTokenToCookie(res, response.accessToken.value, response.accessToken.expires);
        utils_1.attachRefreshTokenToCookie(res, response.refreshToken.value, response.refreshToken.expires);
        utils_1.attachIdRefreshTokenToCookie(res, response.idRefreshToken.value, response.idRefreshToken.expires);
        cookieAndHeaders_1.setAntiCsrfTokenInHeadersIfRequired(res, response.antiCsrfToken);
        return new SuperTokens.Session(response.session.handle, response.session.userId, response.session.jwtPayload, res);
    });
}
//# sourceMappingURL=testLogin.js.map