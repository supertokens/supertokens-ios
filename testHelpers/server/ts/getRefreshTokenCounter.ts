import * as express from 'express';

import RefreshTokenCounter from './refreshTokenCounter';

export async function testGetRefreshCounter(req: express.Request, res: express.Response) {
    res.status(200).send(JSON.stringify({ counter: RefreshTokenCounter.refreshTokenCounter }));
}