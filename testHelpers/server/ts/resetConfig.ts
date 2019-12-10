import * as express from 'express';
import * as SuperTokens from 'supertokens-node-mysql-ref-jwt/express';
import { TypeInputConfig } from 'supertokens-node-mysql-ref-jwt/lib/build/helpers/types';
import {reset} from "supertokens-node-mysql-ref-jwt/lib/build/helpers/utils";
import RefreshTokenCounter from './refreshTokenCounter';
import { defaultConfig } from './index';
import Config from 'supertokens-node-mysql-ref-jwt/lib/build/config';

export default async function resetConfig(req: express.Request, res: express.Response) {
    try {
        if ( req.headers.atvalidity !== undefined && typeof req.headers.atvalidity === "string") {
            let inputValidity = req.headers.atvalidity as string;
            let inputValidityInt = parseInt(inputValidity.trim());
            let newConfig: TypeInputConfig = {
                ...defaultConfig,
                tokens: {
                    ...defaultConfig.tokens,
                    accessToken: {
                        ...defaultConfig.tokens.accessToken,
                        validity: inputValidityInt,
                    }
                }
            }
            RefreshTokenCounter.resetRefreshTokenCount();
            await reset(newConfig);
            let config = Config.get();
            res.status(200).send("");
        } else {
            console.log(`Invalid parameter type provided for atvalidity. Should be string but was ${typeof req.headers.atvalidity}`)
            res.status(400).send("");
        }
    } catch (err) {
        console.log(err);
        res.status(500).send("");
    }
}