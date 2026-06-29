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
const fs = require("fs");

module.exports.executeCommand = async function(cmd) {
    return new Promise((resolve, reject) => {
        console.log("Executing command: " + cmd);
        exec(cmd, (err, stdout, stderr) => {
            if (err) {
                reject({err, stdout, stderr});
                return;
            }
            resolve({ stdout, stderr });
        });
    });
};

module.exports.setupST = async function() {
    const installationPath = shellQuote(getInstallationPath());

    try {
        await module.exports.executeCommand("cd " + installationPath + " && cp temp/licenseKey ./licenseKey");
    } catch (ignored) {}

    await module.exports.executeCommand("cd " + installationPath + " && cp temp/config.yaml ./config.yaml");
};

module.exports.setKeyValueInConfig = async function(key, value) {
    return new Promise((resolve, reject) => {
        const installationPath = getInstallationPath();

        fs.readFile(installationPath + "/config.yaml", "utf8", function(err, data) {
            if (err) {
                reject(err);
                return;
            }

            const oldStr = new RegExp("((#\\s)?)" + key + "(:|((:\\s).+))\n");
            const newStr = key + ": " + value + "\n";
            const result = data.replace(oldStr, newStr);

            fs.writeFile(installationPath + "/config.yaml", result, "utf8", function(err) {
                if (err) {
                    reject(err);
                } else {
                    resolve();
                }
            });
        });
    });
};

module.exports.cleanST = async function() {
    const installationPath = shellQuote(getInstallationPath());

    await module.exports.killAllST();
    await module.exports.executeCommand("cd " + installationPath + " && rm -f licenseKey");
    await module.exports.executeCommand("cd " + installationPath + " && rm -f config.yaml");
    await module.exports.executeCommand("cd " + installationPath + " && rm -rf .webserver-temp-*");
    await module.exports.executeCommand("cd " + installationPath + " && rm -rf .started");
};

module.exports.stopST = async function(pid) {
    let pidsBefore = await getListOfPids();
    if (pidsBefore.length === 0) {
        return;
    }

    if (pid === undefined || pid === null || pid === "") {
        await module.exports.killAllST();
        return;
    }

    await module.exports.executeCommand("kill " + pid);
    const startTime = Date.now();

    while (Date.now() - startTime < 10000) {
        const pidsAfter = await getListOfPids();
        if (pidsAfter.includes(String(pid))) {
            await new Promise(r => setTimeout(r, 100));
        } else {
            return;
        }
    }

    throw new Error("error while stopping ST with PID: " + pid);
};

module.exports.killAllST = async function() {
    const pids = await getListOfPids();

    for (let i = 0; i < pids.length; i++) {
        await module.exports.stopST(pids[i]);
    }
};

module.exports.startST = async function(coreConfig = {}, host = "127.0.0.1", port = Number(process.env.SUPERTOKENS_CORE_PORT || 9000)) {
    for (const [key, value] of Object.entries(coreConfig)) {
        if (value !== undefined) {
            await module.exports.setKeyValueInConfig(key, value);
        }
    }

    return new Promise(async (resolve, reject) => {
        const installationPath = shellQuote(getInstallationPath());
        let returned = false;

        module.exports
            .executeCommand(
                "cd " +
                    installationPath +
                    " && " +
                    getJavaCommand() +
                    ` -Djava.security.egd=file:/dev/urandom -classpath "./core/*:./plugin-interface/*:./ee/*" io.supertokens.Main ./ DEV host=` +
                    host +
                    " port=" +
                    port +
                    " test_mode"
            )
            .catch(({err, stdout, stderr}) => {
                if (!returned) {
                    console.log("Starting ST failed: java command returned early w/ non-zero exit code");
                    console.log(err);
                    console.log(stdout);
                    console.log(stderr);
                    returned = true;
                    reject(err);
                }
            });

        const startTime = Date.now();
        let helloResp;

        while (Date.now() - startTime < 300000) {
            try {
                helloResp = await fetch(`http://${host}:${port}/hello`);
                if (helloResp.status === 200) {
                    console.log("Started ST, it's saying: " + await helloResp.text());
                    returned = true;
                    resolve(`http://${host}:${port}`);
                    return;
                }
            } catch (ex) {
                console.log("Waiting for ST to start, caught exception: " + ex);
            }

            await new Promise(r => setTimeout(r, 100));
        }

        console.log(helloResp);
        returned = true;
        reject("Starting ST process timed out");
    });
};

async function getListOfPids() {
    const installationPath = shellQuote(getInstallationPath());

    try {
        await module.exports.executeCommand("cd " + installationPath + " && ls .started/");
    } catch (err) {
        return [];
    }

    let currList = (await module.exports.executeCommand("cd " + installationPath + " && ls .started/")).stdout;
    currList = currList.split("\n");
    const result = [];

    for (let i = 0; i < currList.length; i++) {
        const item = currList[i];
        if (item === "") {
            continue;
        }

        try {
            const pid = (await module.exports.executeCommand("cd " + installationPath + " && cat .started/" + item))
                .stdout
                .trim();
            result.push(pid);
        } catch (err) {}
    }

    return result;
}

function getInstallationPath() {
    if (process.env.INSTALL_PATH === undefined || process.env.INSTALL_PATH === "") {
        throw new Error("INSTALL_PATH must point to a prepared supertokens-root test environment");
    }

    return process.env.INSTALL_PATH;
}

function shellQuote(value) {
    return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function getJavaCommand() {
    if (process.env.JAVA_HOME !== undefined && process.env.JAVA_HOME !== "") {
        return shellQuote(process.env.JAVA_HOME + "/bin/java");
    }

    return "java";
}

module.exports.maxVersion = function(version1, version2) {
    let splittedv1 = version1.split(".");
    let splittedv2 = version2.split(".");
    let minLength = Math.min(splittedv1.length, splittedv2.length);
    for (let i = 0; i < minLength; i++) {
        let v1 = Number(splittedv1[i]);
        let v2 = Number(splittedv2[i]);
        if (v1 > v2) {
            return version1;
        } else if (v2 > v1) {
            return version2;
        }
    }
    if (splittedv1.length >= splittedv2.length) {
        return version1;
    }
    return version2;
};

module.exports.isProtectedPropName = function (name) {
    return [
        "sub",
        "iat",
        "exp",
        "sessionHandle",
        "parentRefreshTokenHash1",
        "refreshTokenHash1",
        "antiCsrfToken"
    ].includes(name);
};
