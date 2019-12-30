import * as express from 'express';

import RefreshAPIDeviceInfo from './refreshAPIDeviceInfo';

export async function getRefreshDeviceInfo(req: express.Request, res: express.Response) {
    res.status(200).send(JSON.stringify(RefreshAPIDeviceInfo.get()));
}