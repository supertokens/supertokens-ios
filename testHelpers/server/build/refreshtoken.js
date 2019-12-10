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
const SuperTokens = require("supertokens-node");
const refreshTokenCounter_1 = require("./refreshTokenCounter");
function refreshtoken(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            yield SuperTokens.refreshSession(req, res);
            refreshTokenCounter_1.default.incrementRefreshTokenCount();
            res.send("");
        }
        catch (err) {
            if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
                if (err.errType === SuperTokens.Error.TOKEN_THEFT_DETECTED) {
                    yield SuperTokens.revokeSessionUsingSessionHandle(err.err.sessionHandle);
                }
                res.status(440).send("Session expired");
            }
            else {
                throw err;
            }
        }
    });
}
exports.default = refreshtoken;
//# sourceMappingURL=refreshtoken.js.map