export default class RefreshTokenCounter {
    static refreshTokenCounter = 0;

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