"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
class RefreshAPIDeviceInfo {
    static reset() {
        RefreshAPIDeviceInfo.sdkVersion = undefined;
        RefreshAPIDeviceInfo.sdkVersion = undefined;
    }
    static set(sdkName, sdkVersion) {
        RefreshAPIDeviceInfo.sdkName = sdkName;
        RefreshAPIDeviceInfo.sdkVersion = sdkVersion;
    }
    static get() {
        return {
            sdkName: RefreshAPIDeviceInfo.sdkName,
            sdkVersion: RefreshAPIDeviceInfo.sdkVersion
        };
    }
}
RefreshAPIDeviceInfo.sdkName = undefined;
RefreshAPIDeviceInfo.sdkVersion = undefined;
exports.default = RefreshAPIDeviceInfo;
//# sourceMappingURL=refreshAPIDeviceInfo.js.map