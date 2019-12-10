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
const refreshTokenCounter_1 = require("./refreshTokenCounter");
function testGetRefreshCounter(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        res.status(200).send(JSON.stringify({ counter: refreshTokenCounter_1.default.refreshTokenCounter }));
    });
}
exports.testGetRefreshCounter = testGetRefreshCounter;
//# sourceMappingURL=getRefreshTokenCounter.js.map