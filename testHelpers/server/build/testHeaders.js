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
function testHeaders(req, res) {
    return __awaiter(this, void 0, void 0, function* () {
        let testHeader = req.headers["st-custom-header"];
        let success = true;
        if (testHeader === undefined) {
            success = false;
        }
        let data = {
            success,
        };
        res.send(JSON.stringify(data));
    });
}
exports.testHeaders = testHeaders;
//# sourceMappingURL=testHeaders.js.map