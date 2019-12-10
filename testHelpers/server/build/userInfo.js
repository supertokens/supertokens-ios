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
function userInfo(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            let session = yield SuperTokens.getSession(req, res, true);
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
exports.default = userInfo;
//# sourceMappingURL=userInfo.js.map