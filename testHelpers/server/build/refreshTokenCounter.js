"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class RefreshTokenCounter {
    static resetRefreshTokenCount() {
        RefreshTokenCounter.refreshTokenCounter = 0;
    }
    static incrementRefreshTokenCount() {
        RefreshTokenCounter.refreshTokenCounter += 1;
    }
    static getRefreshTokenCounter() {
        return RefreshTokenCounter.refreshTokenCounter;
    }
}
RefreshTokenCounter.refreshTokenCounter = 0;
exports.default = RefreshTokenCounter;
//# sourceMappingURL=refreshTokenCounter.js.map