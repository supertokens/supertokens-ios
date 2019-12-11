import * as cookieParser from 'cookie-parser';
import * as express from 'express';
import * as http from 'http';
import * as SuperTokens from 'supertokens-node';

import { testGetRefreshCounter } from './getRefreshTokenCounter';
import testLogin from './login';
import testLogout from './logout';
import testRefreshtoken from './refreshtoken';
import RefreshTokenCounter from './refreshTokenCounter';
import { testHeaders } from './testHeaders';
import testUserInfo from './userInfo';
import { cleanST, killAllST, setKeyValueInConfig, setupST, startST } from './utils';

let bodyParser = require("body-parser");

let urlencodedParser = bodyParser.urlencoded({ limit: "20mb", extended: true, parameterLimit: 20000 });
let jsonParser = bodyParser.json({ limit: "20mb" });

let app = express();
app.use(urlencodedParser);
app.use(jsonParser);
app.use(cookieParser());

SuperTokens.init([
    {
        hostname: "localhost",
        port: 9000
    }
]);

app.post("/startst", async (req, res) => {
    try {
        let accessTokenValidity = req.body.accessTokenValidity === undefined ? 1 : req.body.accessTokenValidity;
        await setKeyValueInConfig("access_token_validity", accessTokenValidity);
        let pid = await startST();
        res.send(pid + "");
    } catch (err) {
        console.log(err);
    }
});

app.post("/beforeeach", async (req, res) => {
    RefreshTokenCounter.resetRefreshTokenCount();
    await killAllST();
    await setupST();
    await setKeyValueInConfig("cookie_domain", '"127.0.0.1"');
    await setKeyValueInConfig("cookie_secure", "false");
    res.send();
});

app.post("/after", async (req, res) => {
    await killAllST();
    await cleanST();
    res.send();
});

app.post("/login", function (req, res) {
    testLogin(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});

app.get("/userInfo", function (req, res) {
    testUserInfo(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});

app.post("/refresh", function (req, res) {
    testRefreshtoken(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});

app.post("/logout", function (req, res) {
    testLogout(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});

app.get("/refreshCounter", function (req, res) {
    testGetRefreshCounter(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    });
});

app.get("/header", function (req, res) {
    testHeaders(req, res).catch(err => {
        console.log(err);
        res.status(500).send("");
    })
});

app.use("*", function (req, res, next) {
    res.status(404).send("Not found");
});

let server = http.createServer(app);
server.listen(8080, "0.0.0.0");
