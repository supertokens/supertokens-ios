import * as express from 'express';

export async function testHeaders(req: express.Request, res: express.Response) {
    let testHeader = req.headers["st-custom-header"];
    let success = true;
    if (testHeader === undefined) {
        success = false;
    }
    let data = {
        success,
    }

    res.send(JSON.stringify(data));
}