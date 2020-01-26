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
/* Copyright (c) 2020, VRAI Labs and/or its affiliates. All rights reserved.
 *
 * This software is licensed under the Apache License, Version 2.0 (the
 * "License") as published by the Apache Software Foundation.
 *
 * You may not use this file except in compliance with the License. You may
 * obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 * License for the specific language governing permissions and limitations
 * under the License.
 */
const { exec } = require("child_process");
let { HandshakeInfo } = require("supertokens-node/lib/build/handshakeInfo");
let { DeviceInfo } = require("supertokens-node/lib/build/deviceInfo");
let { setCookie } = require("supertokens-node/lib/build/cookieAndHeaders");
let fs = require("fs");
function executeCommand(cmd) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => {
            exec(cmd, (err, stdout, stderr) => {
                if (err) {
                    reject(err);
                    return;
                }
                resolve({ stdout, stderr });
            });
        });
    });
}
exports.executeCommand = executeCommand;
;
function setupST() {
    return __awaiter(this, void 0, void 0, function* () {
        let installationPath = process.env.INSTALL_PATH;
        yield executeCommand("cd " + installationPath + " && cp temp/licenseKey ./licenseKey");
        yield executeCommand("cd " + installationPath + " && cp temp/config.yaml ./config.yaml");
    });
}
exports.setupST = setupST;
;
function setKeyValueInConfig(key, value) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => {
            let installationPath = process.env.INSTALL_PATH;
            fs.readFile(installationPath + "/config.yaml", "utf8", function (err, data) {
                if (err) {
                    reject(err);
                    return;
                }
                let oldStr = new RegExp("((#\\s)?)" + key + "(:|((:\\s).+))\n");
                let newStr = key + ": " + value + "\n";
                let result = data.replace(oldStr, newStr);
                fs.writeFile(installationPath + "/config.yaml", result, "utf8", function (err) {
                    if (err) {
                        reject(err);
                    }
                    else {
                        resolve();
                    }
                });
            });
        });
    });
}
exports.setKeyValueInConfig = setKeyValueInConfig;
;
function cleanST() {
    return __awaiter(this, void 0, void 0, function* () {
        let installationPath = process.env.INSTALL_PATH;
        yield executeCommand("cd " + installationPath + " && rm licenseKey");
        yield executeCommand("cd " + installationPath + " && rm config.yaml");
        yield executeCommand("cd " + installationPath + " && rm -rf .webserver-temp-*");
        yield executeCommand("cd " + installationPath + " && rm -rf .started");
    });
}
exports.cleanST = cleanST;
;
function stopST(pid) {
    return __awaiter(this, void 0, void 0, function* () {
        let pidsBefore = yield getListOfPids();
        if (pidsBefore.length === 0) {
            return;
        }
        yield executeCommand("kill " + pid);
        let startTime = Date.now();
        while (Date.now() - startTime < 10000) {
            let pidsAfter = yield getListOfPids();
            if (pidsAfter.includes(pid)) {
                yield new Promise(r => setTimeout(r, 100));
                continue;
            }
            else {
                return;
            }
        }
        throw new Error("error while stopping ST with PID: " + pid);
    });
}
exports.stopST = stopST;
;
function killAllST() {
    return __awaiter(this, void 0, void 0, function* () {
        let pids = yield getListOfPids();
        for (let i = 0; i < pids.length; i++) {
            yield stopST(pids[i]);
        }
        HandshakeInfo.reset();
        DeviceInfo.reset();
    });
}
exports.killAllST = killAllST;
;
function startST(host = "localhost", port = 9000) {
    return __awaiter(this, void 0, void 0, function* () {
        return new Promise((resolve, reject) => __awaiter(this, void 0, void 0, function* () {
            let installationPath = process.env.INSTALL_PATH;
            let pidsBefore = yield getListOfPids();
            let returned = false;
            let javaPath = process.env.JAVA === undefined ? "java" : process.env.JAVA;
            executeCommand("cd " +
                installationPath +
                ` && ${javaPath} -classpath "./core/*:./plugin-interface/*" io.supertokens.Main ./ DEV host=` +
                host +
                " port=" +
                port)
                .catch((err) => {
                if (!returned) {
                    returned = true;
                    reject(err);
                }
            });
            let startTime = Date.now();
            while (Date.now() - startTime < 20000) {
                let pidsAfter = yield getListOfPids();
                if (pidsAfter.length <= pidsBefore.length) {
                    yield new Promise(r => setTimeout(r, 100));
                    continue;
                }
                let nonIntersection = pidsAfter.filter(x => !pidsBefore.includes(x));
                if (nonIntersection.length !== 1) {
                    if (!returned) {
                        returned = true;
                        reject("something went wrong while starting ST");
                    }
                }
                else {
                    if (!returned) {
                        returned = true;
                        resolve(nonIntersection[0]);
                    }
                }
            }
            if (!returned) {
                returned = true;
                reject("could not start ST process");
            }
        }));
    });
}
exports.startST = startST;
;
function getListOfPids() {
    return __awaiter(this, void 0, void 0, function* () {
        let installationPath = process.env.INSTALL_PATH;
        try {
            (yield executeCommand("cd " + installationPath + " && ls .started/")).stdout;
        }
        catch (err) {
            return [];
        }
        let currList = (yield executeCommand("cd " + installationPath + " && ls .started/")).stdout;
        currList = currList.split("\n");
        let result = [];
        for (let i = 0; i < currList.length; i++) {
            let item = currList[i];
            if (item === "") {
                continue;
            }
            try {
                let pid = (yield executeCommand("cd " + installationPath + " && cat .started/" + item))
                    .stdout;
                result.push(pid);
            }
            catch (err) { }
        }
        return result;
    });
}
//# sourceMappingURL=utils.js.map