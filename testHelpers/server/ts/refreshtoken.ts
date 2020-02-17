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
import * as express from 'express';
import * as SuperTokens from 'supertokens-node';

import RefreshAPICustomHeader from './refreshAPICustomHeader';
import RefreshAPIDeviceInfo from './refreshAPIDeviceInfo';
import RefreshTokenCounter from './refreshTokenCounter';

export default async function refreshtoken(req: express.Request, res: express.Response) {
    try {
        let sdkName: any = req.headers["supertokens-sdk-name"];
        let sdkVersion: any = req.headers["supertokens-sdk-version"];
        let customValue: any = req.headers["custom-header"];
        await SuperTokens.refreshSession(req, res);
        RefreshTokenCounter.incrementRefreshTokenCount();
        RefreshAPIDeviceInfo.set(sdkName, sdkVersion);
        if (customValue === "custom-value") {
            RefreshAPICustomHeader.set(customValue);
        }
        res.send("");
    } catch (err) {
        if (SuperTokens.Error.isErrorFromAuth(err) && err.errType !== SuperTokens.Error.GENERAL_ERROR) {
            if (err.errType === SuperTokens.Error.TOKEN_THEFT_DETECTED) {
                await SuperTokens.revokeSessionUsingSessionHandle(err.err.sessionHandle);
            }
            res.status(440).send("Session expired");
        } else {
            throw err;
        }
    }
} 