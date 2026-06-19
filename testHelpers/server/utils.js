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
let network;
let postgresContainer;
let coreContainer;
let currentCoreConfig;
const DEFAULT_SUPERTOKENS_CORE_IMAGE = "supertokens/supertokens-postgresql:11.3.5";
const DEFAULT_POSTGRES_IMAGE = "postgres:14.19-alpine";
const CONTAINER_STARTUP_TIMEOUT_MS = Number(process.env.TESTCONTAINERS_STARTUP_TIMEOUT_MS || 300000);

module.exports.setupST = async function() {
    await module.exports.cleanST();
    await ensurePostgresContainer();
};

module.exports.setKeyValueInConfig = async function(key, value) {
    currentCoreConfig = {
        ...(currentCoreConfig || defaultCoreConfig()),
        [key]: value
    };
};

module.exports.cleanST = async function() {
    try {
        await stopCoreContainer();
    } finally {
        try {
            if (postgresContainer) {
                await postgresContainer.stop();
                postgresContainer = undefined;
            }
        } finally {
            if (network) {
                await network.stop();
                network = undefined;
            }
            currentCoreConfig = undefined;
        }
    }
};

module.exports.stopST = async function(pid) {
    await stopCoreContainer();
};

module.exports.killAllST = async function() {
    await stopCoreContainer();
};

module.exports.startST = async function(coreConfig = {}) {
    await ensurePostgresContainer();
    await stopCoreContainer();

    currentCoreConfig = {
        ...defaultCoreConfig(),
        ...(currentCoreConfig || {}),
        ...coreConfig
    };

    const { GenericContainer, Wait } = await import("testcontainers");
    const image = process.env.SUPERTOKENS_CORE_IMAGE || DEFAULT_SUPERTOKENS_CORE_IMAGE;
    const coreEnvironment = {
        POSTGRESQL_CONNECTION_URI: "postgresql://supertokens:somepassword@postgres:5432/supertokens",
        DISABLE_TELEMETRY: "true",
        ...toCoreEnvironment(currentCoreConfig)
    };

    coreContainer = await new GenericContainer(image)
        .withNetwork(network)
        .withEnvironment(coreEnvironment)
        .withExposedPorts(3567)
        .withWaitStrategy(Wait.forHttp("/hello", 3567, { abortOnContainerExit: true }).forStatusCode(200))
        .withStartupTimeout(CONTAINER_STARTUP_TIMEOUT_MS)
        .start();

    const connectionURI = `http://${coreContainer.getHost()}:${coreContainer.getMappedPort(3567)}`;
    const helloResp = await fetch(`${connectionURI}/hello`);
    console.log(`Started ST from ${image}, it's saying: ${await helloResp.text()}`);
    return connectionURI;
};

async function ensurePostgresContainer() {
    if (postgresContainer) {
        return;
    }

    const { GenericContainer, Network, Wait } = await import("testcontainers");
    network = await new Network().start();
    postgresContainer = await new GenericContainer(process.env.POSTGRES_IMAGE || DEFAULT_POSTGRES_IMAGE)
        .withNetwork(network)
        .withNetworkAliases("postgres")
        .withEnvironment({
            POSTGRES_USER: "supertokens",
            POSTGRES_PASSWORD: "somepassword",
            POSTGRES_DB: "supertokens"
        })
        .withExposedPorts(5432)
        .withWaitStrategy(Wait.forLogMessage("database system is ready to accept connections", 2))
        .withStartupTimeout(CONTAINER_STARTUP_TIMEOUT_MS)
        .start();
}

async function stopCoreContainer() {
    if (!coreContainer) {
        return;
    }
    await coreContainer.stop();
    coreContainer = undefined;
}

function defaultCoreConfig() {
    return {
        access_token_validity: 1
    };
}

function toCoreEnvironment(config) {
    const env = {};

    if (config.access_token_validity !== undefined) {
        env.ACCESS_TOKEN_VALIDITY = String(config.access_token_validity);
    }
    if (config.refresh_token_validity !== undefined) {
        env.REFRESH_TOKEN_VALIDITY = String(config.refresh_token_validity);
    }
    if (config.access_token_signing_key_update_interval !== undefined) {
        env.ACCESS_TOKEN_DYNAMIC_SIGNING_KEY_UPDATE_INTERVAL = String(config.access_token_signing_key_update_interval);
    }

    return env;
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
