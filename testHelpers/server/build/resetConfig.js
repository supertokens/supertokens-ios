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
const utils_1 = require("supertokens-node-mysql-ref-jwt/lib/build/helpers/utils");
const refreshTokenCounter_1 = require("./refreshTokenCounter");
const index_1 = require("./index");
const config_1 = require("supertokens-node-mysql-ref-jwt/lib/build/config");
function resetConfig(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            if (req.headers.atvalidity !== undefined && typeof req.headers.atvalidity === "string") {
                let inputValidity = req.headers.atvalidity;
                let inputValidityInt = parseInt(inputValidity.trim());
                let newConfig = Object.assign({}, index_1.defaultConfig, { tokens: Object.assign({}, index_1.defaultConfig.tokens, { accessToken: Object.assign({}, index_1.defaultConfig.tokens.accessToken, { validity: inputValidityInt }) }) });
                refreshTokenCounter_1.default.resetRefreshTokenCount();
                yield utils_1.reset(newConfig);
                let config = config_1.default.get();
                res.status(200).send("");
            }
            else {
                console.log(`Invalid parameter type provided for atvalidity. Should be string but was ${typeof req.headers.atvalidity}`);
                res.status(400).send("");
            }
        }
        catch (err) {
            console.log(err);
            res.status(500).send("");
        }
    });
}
exports.default = resetConfig;
//# sourceMappingURL=resetConfig.js.map