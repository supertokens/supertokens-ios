export default class RefreshAPIDeviceInfo {
    static sdkName: string | undefined = undefined;
    static sdkVersion: string | undefined = undefined;

    static reset() {
        RefreshAPIDeviceInfo.sdkVersion = undefined;
        RefreshAPIDeviceInfo.sdkVersion = undefined;
    }

    static set(sdkName: string, sdkVersion: string) {
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